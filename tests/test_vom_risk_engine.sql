--------------------------------------------------------------------------------
-- utPLSQL suite for vom_risk_engine
--   Run: exec ut.run('test_vom_risk_engine');
--   Each test runs inside a savepoint and is rolled back automatically.
--------------------------------------------------------------------------------
create or replace package test_vom_risk_engine as
  --%suite(Vendor risk engine)

  --%test(Score thresholds map to LOW / MEDIUM / HIGH)
  procedure level_thresholds;

  --%test(Complete low-spend vendor in a normal category is LOW risk)
  procedure complete_vendor_is_low;

  --%test(High-risk country, critical category and missing documents give HIGH risk)
  procedure risky_vendor_is_high;

  --%test(Every active factor is recorded with a score)
  procedure factors_are_explainable;
end test_vom_risk_engine;
/

create or replace package body test_vom_risk_engine as

  function new_vendor (p_country varchar2, p_category varchar2, p_spend varchar2, p_tax varchar2) return number is
  begin
    return vom_vendor_api.create_vendor('Test Vendor ' || dbms_random.string('X', 6), p_country, p_category,
                                        'test@example.com', p_tax, p_spend);
  end new_vendor;

  procedure add_valid_doc (p_vendor number, p_type varchar2) is
  begin
    insert into vom_vendor_documents (vendor_id, doc_type_code, file_name, mime_type, issued_on, expires_on, status, uploaded_by)
    values (p_vendor, p_type, 'f.pdf', 'application/pdf', sysdate - 10, add_months(sysdate, 12), 'VALID', 'UT');
  end add_valid_doc;

  procedure level_thresholds is
  begin
    ut.expect(vom_risk_engine.level_for(0)).to_equal('LOW');
    ut.expect(vom_risk_engine.level_for(29.99)).to_equal('LOW');
    ut.expect(vom_risk_engine.level_for(30)).to_equal('MEDIUM');
    ut.expect(vom_risk_engine.level_for(59.99)).to_equal('MEDIUM');
    ut.expect(vom_risk_engine.level_for(60)).to_equal('HIGH');
  end level_thresholds;

  procedure complete_vendor_is_low is
    l_id number := new_vendor('GB', 'FACILITIES', 'LOW', 'GB123');
  begin
    add_valid_doc(l_id, 'TRADE_LICENSE');
    add_valid_doc(l_id, 'TAX_CERT');
    add_valid_doc(l_id, 'BANK_LETTER');
    ut.expect(vom_risk_engine.calculate(l_id)).to_equal('LOW');
  end complete_vendor_is_low;

  procedure risky_vendor_is_high is
    l_id number := new_vendor('XA', 'RAW_MATERIALS', 'HIGH', null);
  begin
    ut.expect(vom_risk_engine.calculate(l_id)).to_equal('HIGH');
  end risky_vendor_is_high;

  procedure factors_are_explainable is
    l_id     number := new_vendor('GB', 'IT_SERVICES', 'MEDIUM', 'GB999');
    l_count  number;
    l_active number;
  begin
    vom_risk_engine.calculate(l_id);
    select count(*) into l_count from vom_vendor_risk where vendor_id = l_id;
    select count(*) into l_active from vom_risk_factors where active_yn = 'Y';
    ut.expect(l_count).to_equal(l_active);
  end factors_are_explainable;

end test_vom_risk_engine;
/
