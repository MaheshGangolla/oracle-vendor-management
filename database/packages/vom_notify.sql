--------------------------------------------------------------------------------
-- vom_notify : e-mail notifications through APEX_MAIL
--   Requires the APEX instance mail server to be configured.
--   Messages are queued; APEX sends the queue in the background.
--   The sender address comes from VOM_LOOKUPS (type MAIL, code FROM_ADDRESS).
--------------------------------------------------------------------------------
create or replace package vom_notify as

  procedure notify_approvers (p_vendor_id in number);

  procedure notify_vendor_outcome (p_vendor_id in number);

  -- Daily job: reminders for documents expiring within 30 days
  procedure send_expiry_reminders;

end vom_notify;
/

create or replace package body vom_notify as

  function sender return varchar2 is
    l_from vom_lookups.meaning%type;
  begin
    select meaning into l_from from vom_lookups where lookup_type = 'MAIL' and code = 'FROM_ADDRESS';
    return l_from;
  exception
    when no_data_found then
      return 'no-reply@example.com';
  end sender;

  procedure send (p_to in varchar2, p_subject in varchar2, p_body in varchar2) is
    l_id number;
  begin
    if p_to is null then
      return;
    end if;
    l_id := apex_mail.send(p_to => p_to, p_from => sender, p_subj => p_subject, p_body => p_body);
  exception
    when others then
      -- Notification failure must never roll back a business transaction
      vom_util.audit('MAIL', 0, 'SEND_FAILED', null, null, p_subject || ' -> ' || sqlerrm);
  end send;

  procedure notify_approvers (p_vendor_id in number) is
  begin
    for r in (select u.username, v.vendor_name, v.risk_level, s.approver_role
                from vom_approval_steps s
                join vom_vendors v     on v.vendor_id = s.vendor_id
                join vom_user_roles u  on u.role_code = s.approver_role
               where s.vendor_id = p_vendor_id
                 and s.status = 'PENDING'
                 and instr(u.username, '@') > 0)
    loop
      send(r.username,
           'Approval needed: ' || r.vendor_name,
           'Vendor ' || r.vendor_name || ' (risk ' || r.risk_level || ') is waiting for ' ||
           r.approver_role || ' approval. Open "My Approvals" in the Vendor Onboarding application.');
    end loop;
  end notify_approvers;

  procedure notify_vendor_outcome (p_vendor_id in number) is
  begin
    for v in (select vendor_name, primary_email, status, vendor_number
                from vom_vendors where vendor_id = p_vendor_id)
    loop
      send(v.primary_email,
           'Vendor registration ' || lower(v.status) || ': ' || v.vendor_name,
           case v.status
             when 'APPROVED' then 'Your registration is approved. Vendor number: ' || v.vendor_number || '.'
             else 'Your registration was not approved. Our procurement team will contact you with details.'
           end);
    end loop;
  end notify_vendor_outcome;

  procedure send_expiry_reminders is
  begin
    vom_document_mgr.refresh_statuses;
    for d in (select v.primary_email, v.vendor_name, t.doc_type_name, x.expires_on
                from vom_vendor_documents x
                join vom_vendors v        on v.vendor_id = x.vendor_id
                join vom_document_types t on t.doc_type_code = x.doc_type_code
               where x.status = 'EXPIRING'
                 and v.status = 'APPROVED')
    loop
      send(d.primary_email,
           'Document expiring: ' || d.doc_type_name,
           'Dear ' || d.vendor_name || ', your ' || d.doc_type_name || ' expires on ' ||
           to_char(d.expires_on, 'DD-Mon-YYYY') || '. Please upload a renewed copy.');
    end loop;
    apex_mail.push_queue;
  end send_expiry_reminders;

end vom_notify;
/
