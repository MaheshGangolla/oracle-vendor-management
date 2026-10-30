--------------------------------------------------------------------------------
-- vom_risk_engine : weighted, explainable vendor risk scoring
--   score per factor 0..100, weighted average 0..100
--   level: HIGH >= 60, MEDIUM >= 30, else LOW
--   factor weights live in VOM_RISK_FACTORS and can be changed without code
--------------------------------------------------------------------------------
create or replace package vom_risk_engine as

  c_high_threshold   constant number := 60;
  c_medium_threshold constant number := 30;

  function level_for (p_score in number) return varchar2;

  -- Recalculates factor scores, total score and level; returns the level
  function calculate (p_vendor_id in number) return varchar2;

  procedure calculate (p_vendor_id in number);

end vom_risk_engine;
/

create or replace package body vom_risk_engine as

  function level_for (p_score in number) return varchar2 is
  begin
    return case
             when p_score >= c_high_threshold   then 'HIGH'
             when p_score >= c_medium_threshold then 'MEDIUM'
             else 'LOW'
           end;
  end level_for;

  function in_lookup (p_type in varchar2, p_code in varchar2) return boolean is
    l_count pls_integer;
  begin
    select count(*) into l_count
      from vom_lookups
     where lookup_type = p_type and code = p_code and active_yn = 'Y';
    return l_count > 0;
  end in_lookup;

  procedure set_factor (p_vendor_id in number, p_factor in varchar2, p_score in number, p_notes in varchar2) is
  begin
    merge into vom_vendor_risk r
    using (select p_vendor_id vendor_id, p_factor factor_code from dual) s
       on (r.vendor_id = s.vendor_id and r.factor_code = s.factor_code)
     when matched then update set r.score = p_score, r.notes = p_notes
     when not matched then insert (vendor_id, factor_code, score, notes)
                           values (p_vendor_id, p_factor, p_score, p_notes);
  end set_factor;

  function calculate (p_vendor_id in number) return varchar2 is
    l_vendor   vom_vendors%rowtype;
    l_expired  pls_integer;
    l_expiring pls_integer;
    l_missing  varchar2(4000);
    l_score    number;
    l_level    varchar2(10);
  begin
    select * into l_vendor from vom_vendors where vendor_id = p_vendor_id for update;

    -- 1. Country risk
    if in_lookup('HIGH_RISK_COUNTRY', l_vendor.country_code) then
      set_factor(p_vendor_id, 'COUNTRY', 100, 'Country is on the high-risk list');
    else
      set_factor(p_vendor_id, 'COUNTRY', 0, null);
    end if;

    -- 2. Category criticality
    if in_lookup('CRITICAL_CATEGORY', l_vendor.category_code) then
      set_factor(p_vendor_id, 'CATEGORY', 100, 'Business-critical supply category');
    else
      set_factor(p_vendor_id, 'CATEGORY', 20, null);
    end if;

    -- 3. Spend exposure
    set_factor(p_vendor_id, 'SPEND',
               case l_vendor.annual_spend_band when 'HIGH' then 100 when 'MEDIUM' then 50 else 10 end,
               'Annual spend band: ' || nvl(l_vendor.annual_spend_band, 'not provided'));

    -- 4. Compliance documents
    vom_document_mgr.refresh_statuses(p_vendor_id);
    l_missing := vom_document_mgr.missing_mandatory_docs(p_vendor_id);
    select count(case when status = 'EXPIRED'  then 1 end),
           count(case when status = 'EXPIRING' then 1 end)
      into l_expired, l_expiring
      from vom_vendor_documents
     where vendor_id = p_vendor_id;
    set_factor(p_vendor_id, 'DOCUMENTS',
               case when l_missing is not null or l_expired > 0 then 100 when l_expiring > 0 then 50 else 0 end,
               case when l_missing is not null then 'Missing: ' || l_missing
                    when l_expired  > 0 then l_expired  || ' expired document(s)'
                    when l_expiring > 0 then l_expiring || ' document(s) expiring soon' end);

    -- 5. Tax registration
    set_factor(p_vendor_id, 'TAX_ID',
               case when l_vendor.tax_registration_no is null then 100 else 0 end,
               case when l_vendor.tax_registration_no is null then 'Tax registration number not provided' end);

    -- Weighted average across active factors
    select round(sum(r.score * f.weight) / nullif(sum(f.weight), 0), 2)
      into l_score
      from vom_vendor_risk r
      join vom_risk_factors f on f.factor_code = r.factor_code
     where r.vendor_id = p_vendor_id
       and f.active_yn = 'Y';

    l_level := level_for(nvl(l_score, 0));

    update vom_vendors
       set risk_score = l_score, risk_level = l_level, risk_calculated_on = sysdate
     where vendor_id = p_vendor_id;

    vom_util.audit('VENDOR', p_vendor_id, 'RISK_CALCULATED', l_vendor.risk_level, l_level,
                   'Score ' || to_char(l_score, 'FM990.00'));
    return l_level;
  end calculate;

  procedure calculate (p_vendor_id in number) is
    l_level varchar2(10);
  begin
    l_level := calculate(p_vendor_id);
  end calculate;

end vom_risk_engine;
/
