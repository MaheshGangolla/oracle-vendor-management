--------------------------------------------------------------------------------
-- vom_vendor_api : the only entry point APEX pages use to change vendors
--------------------------------------------------------------------------------
create or replace package vom_vendor_api as

  function create_vendor (
    p_vendor_name          in varchar2,
    p_country_code         in varchar2,
    p_category_code        in varchar2,
    p_primary_email        in varchar2,
    p_tax_registration_no  in varchar2 default null,
    p_annual_spend_band    in varchar2 default null,
    p_primary_contact_name in varchar2 default null,
    p_phone                in varchar2 default null,
    p_website              in varchar2 default null
  ) return number;

  -- Validates completeness, then starts the risk-based approval chain
  procedure submit (p_vendor_id in number);

  procedure suspend (p_vendor_id in number, p_reason in varchar2);

  procedure reactivate (p_vendor_id in number);

end vom_vendor_api;
/

create or replace package body vom_vendor_api as

  function create_vendor (
    p_vendor_name          in varchar2,
    p_country_code         in varchar2,
    p_category_code        in varchar2,
    p_primary_email        in varchar2,
    p_tax_registration_no  in varchar2 default null,
    p_annual_spend_band    in varchar2 default null,
    p_primary_contact_name in varchar2 default null,
    p_phone                in varchar2 default null,
    p_website              in varchar2 default null
  ) return number is
    l_id vom_vendors.vendor_id%type;
  begin
    insert into vom_vendors (vendor_name, country_code, category_code, primary_email, tax_registration_no,
                             annual_spend_band, primary_contact_name, phone, website, created_by)
    values (trim(p_vendor_name), upper(p_country_code), p_category_code, lower(trim(p_primary_email)),
            upper(trim(p_tax_registration_no)), p_annual_spend_band, p_primary_contact_name, p_phone,
            p_website, vom_util.current_user)
    returning vendor_id into l_id;

    vom_util.audit('VENDOR', l_id, 'CREATE', null, 'DRAFT');
    return l_id;
  exception
    when dup_val_on_index then
      raise_application_error(-20300, 'A vendor with this tax registration number already exists for this country.');
  end create_vendor;

  procedure submit (p_vendor_id in number) is
    l_status  vom_vendors.status%type;
    l_missing varchar2(4000);
  begin
    select status into l_status from vom_vendors where vendor_id = p_vendor_id for update;

    if l_status not in ('DRAFT', 'REJECTED') then
      raise_application_error(-20301, 'Only draft or rejected vendors can be submitted (current status: ' || l_status || ').');
    end if;

    l_missing := vom_document_mgr.missing_mandatory_docs(p_vendor_id);
    if l_missing is not null then
      raise_application_error(-20302, 'Upload the mandatory documents before submitting: ' || l_missing || '.');
    end if;

    update vom_vendors set status = 'SUBMITTED', updated_by = vom_util.current_user, updated_on = sysdate
     where vendor_id = p_vendor_id;
    vom_util.audit('VENDOR', p_vendor_id, 'SUBMIT', l_status, 'SUBMITTED');

    vom_workflow.start_approval(p_vendor_id);
  end submit;

  procedure suspend (p_vendor_id in number, p_reason in varchar2) is
  begin
    vom_security.assert_role('COMPLIANCE');
    if p_reason is null then
      raise_application_error(-20303, 'A reason is required to suspend a vendor.');
    end if;
    update vom_vendors set status = 'SUSPENDED', updated_by = vom_util.current_user, updated_on = sysdate
     where vendor_id = p_vendor_id and status = 'APPROVED';
    if sql%rowcount = 0 then
      raise_application_error(-20304, 'Only approved vendors can be suspended.');
    end if;
    vom_util.audit('VENDOR', p_vendor_id, 'SUSPEND', 'APPROVED', 'SUSPENDED', p_reason);
  end suspend;

  procedure reactivate (p_vendor_id in number) is
  begin
    vom_security.assert_role('COMPLIANCE');
    if not vom_document_mgr.is_complete(p_vendor_id) then
      raise_application_error(-20305, 'Mandatory documents must be valid before reactivation.');
    end if;
    update vom_vendors set status = 'APPROVED', updated_by = vom_util.current_user, updated_on = sysdate
     where vendor_id = p_vendor_id and status = 'SUSPENDED';
    if sql%rowcount = 0 then
      raise_application_error(-20306, 'Only suspended vendors can be reactivated.');
    end if;
    vom_util.audit('VENDOR', p_vendor_id, 'REACTIVATE', 'SUSPENDED', 'APPROVED');
  end reactivate;

end vom_vendor_api;
/
