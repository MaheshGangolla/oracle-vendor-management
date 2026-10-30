--------------------------------------------------------------------------------
-- 02_sample_data.sql : synthetic demo data (optional; do not run in production)
-- All names, e-mail addresses and numbers are fictitious.
--------------------------------------------------------------------------------

-- Demo users: replace with your APEX workspace usernames
insert into vom_user_roles (username, role_code, granted_by) values ('DEMO_ADMIN',       'ADMIN',       'INSTALL');
insert into vom_user_roles (username, role_code, granted_by) values ('DEMO_PROCUREMENT', 'PROCUREMENT', 'INSTALL');
insert into vom_user_roles (username, role_code, granted_by) values ('DEMO_COMPLIANCE',  'COMPLIANCE',  'INSTALL');
insert into vom_user_roles (username, role_code, granted_by) values ('DEMO_FINANCE',     'FINANCE',     'INSTALL');

declare
  l_id number;

  procedure add_doc (p_vendor in number, p_type in varchar2, p_issued in date, p_expires in date, p_status in varchar2) is
  begin
    insert into vom_vendor_documents (vendor_id, doc_type_code, file_name, mime_type, issued_on, expires_on, status, uploaded_by)
    values (p_vendor, p_type, lower(p_type) || '.pdf', 'application/pdf', p_issued, p_expires, p_status, 'INSTALL');
  end add_doc;
begin
  -- 1. Complete, low-risk IT supplier
  l_id := vom_vendor_api.create_vendor('Sample Cloud Services Ltd', 'GB', 'IT_SERVICES', 'accounts@sample-cloud.example.com',
                                       'GB100200300', 'LOW', 'Alex Morgan', '+44 20 0000 0001', 'https://sample-cloud.example.com');
  add_doc(l_id, 'TRADE_LICENSE',   add_months(sysdate, -2), add_months(sysdate, 10), 'VALID');
  add_doc(l_id, 'TAX_CERT',        add_months(sysdate, -6), add_months(sysdate, 18), 'VALID');
  add_doc(l_id, 'BANK_LETTER',     add_months(sysdate, -1), null,                     'VALID');
  add_doc(l_id, 'DATA_PROTECTION', add_months(sysdate, -3), add_months(sysdate, 21), 'VALID');

  -- 2. Logistics provider with an insurance certificate expiring soon (medium/high risk)
  l_id := vom_vendor_api.create_vendor('Example Freight Partners', 'DE', 'LOGISTICS', 'onboarding@example-freight.example.com',
                                       'DE998877665', 'HIGH', 'Priya Raman', '+49 30 0000 0002', null);
  add_doc(l_id, 'TRADE_LICENSE', add_months(sysdate, -4),  add_months(sysdate, 8), 'VALID');
  add_doc(l_id, 'TAX_CERT',      add_months(sysdate, -12), add_months(sysdate, 12), 'VALID');
  add_doc(l_id, 'BANK_LETTER',   add_months(sysdate, -2),  null,                    'VALID');
  add_doc(l_id, 'INSURANCE',     add_months(sysdate, -11), sysdate + 20,            'EXPIRING');

  -- 3. Raw-material supplier missing its bank confirmation (cannot be submitted yet)
  l_id := vom_vendor_api.create_vendor('Demo Metals Trading Co', 'XA', 'RAW_MATERIALS', 'sales@demo-metals.example.com',
                                       null, 'MEDIUM', 'Daniel Okafor', null, null);
  add_doc(l_id, 'TRADE_LICENSE', add_months(sysdate, -1), add_months(sysdate, 11), 'PENDING');
end;
/

commit;
