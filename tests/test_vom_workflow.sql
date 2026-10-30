--------------------------------------------------------------------------------
-- utPLSQL suite for vom_vendor_api + vom_workflow
--   Run: exec ut.run('test_vom_workflow');
--------------------------------------------------------------------------------
create or replace package test_vom_workflow as
  --%suite(Vendor submission and approval workflow)

  --%beforeeach
  procedure grant_all_roles;

  --%test(Submitting without mandatory documents is refused)
  --%throws(-20302)
  procedure submit_requires_documents;

  --%test(High-risk vendor gets a three-step chain with only step 1 pending)
  procedure high_risk_chain;

  --%test(Approving every step approves the vendor and assigns a vendor number)
  procedure full_approval;

  --%test(A rejection rejects the vendor and cancels waiting steps)
  procedure rejection_cancels_chain;

  --%test(Rejecting without a comment is refused)
  --%throws(-20202)
  procedure reject_requires_comment;
end test_vom_workflow;
/

create or replace package body test_vom_workflow as

  procedure grant_all_roles is
  begin
    insert into vom_user_roles (username, role_code) values (vom_util.current_user, 'ADMIN');
  end grant_all_roles;

  function complete_vendor (p_country varchar2, p_category varchar2, p_spend varchar2, p_tax varchar2) return number is
    l_id number;
  begin
    l_id := vom_vendor_api.create_vendor('WF Vendor ' || dbms_random.string('X', 6), p_country, p_category,
                                         'wf@example.com', p_tax, p_spend);
    for t in (select doc_type_code from vom_document_types
               where mandatory_yn = 'Y' and (category_code is null or category_code = p_category))
    loop
      insert into vom_vendor_documents (vendor_id, doc_type_code, file_name, mime_type, issued_on, expires_on, status, uploaded_by)
      values (l_id, t.doc_type_code, 'f.pdf', 'application/pdf', sysdate - 10, add_months(sysdate, 12), 'VALID', 'UT');
    end loop;
    return l_id;
  end complete_vendor;

  function pending_step (p_vendor number) return number is
    l_step number;
  begin
    select step_id into l_step from vom_approval_steps where vendor_id = p_vendor and status = 'PENDING';
    return l_step;
  end pending_step;

  procedure submit_requires_documents is
    l_id number := vom_vendor_api.create_vendor('No Docs Ltd', 'GB', 'FACILITIES', 'nodocs@example.com', 'GB1', 'LOW');
  begin
    vom_vendor_api.submit(l_id);
  end submit_requires_documents;

  procedure high_risk_chain is
    l_id      number := complete_vendor('XA', 'RAW_MATERIALS', 'HIGH', null);
    l_steps   number;
    l_pending number;
  begin
    vom_vendor_api.submit(l_id);
    select count(*), count(case when status = 'PENDING' then 1 end)
      into l_steps, l_pending
      from vom_approval_steps where vendor_id = l_id;
    ut.expect(l_steps).to_equal(3);
    ut.expect(l_pending).to_equal(1);
  end high_risk_chain;

  procedure full_approval is
    l_id     number := complete_vendor('XA', 'RAW_MATERIALS', 'HIGH', null);
    l_status vom_vendors.status%type;
    l_number vom_vendors.vendor_number%type;
  begin
    vom_vendor_api.submit(l_id);
    for i in 1 .. 3 loop
      vom_workflow.decide(pending_step(l_id), 'APPROVED', 'ok');
    end loop;
    select status, vendor_number into l_status, l_number from vom_vendors where vendor_id = l_id;
    ut.expect(l_status).to_equal('APPROVED');
    ut.expect(l_number).to_be_not_null();
  end full_approval;

  procedure rejection_cancels_chain is
    l_id        number := complete_vendor('XA', 'RAW_MATERIALS', 'HIGH', null);
    l_status    vom_vendors.status%type;
    l_cancelled number;
  begin
    vom_vendor_api.submit(l_id);
    vom_workflow.decide(pending_step(l_id), 'REJECTED', 'Sanctions screening failed');
    select status into l_status from vom_vendors where vendor_id = l_id;
    select count(*) into l_cancelled from vom_approval_steps where vendor_id = l_id and status = 'CANCELLED';
    ut.expect(l_status).to_equal('REJECTED');
    ut.expect(l_cancelled).to_equal(2);
  end rejection_cancels_chain;

  procedure reject_requires_comment is
    l_id number := complete_vendor('GB', 'FACILITIES', 'LOW', 'GB2');
  begin
    vom_vendor_api.submit(l_id);
    vom_workflow.decide(pending_step(l_id), 'REJECTED', null);
  end reject_requires_comment;

end test_vom_workflow;
/
