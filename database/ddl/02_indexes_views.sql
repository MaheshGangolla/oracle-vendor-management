--------------------------------------------------------------------------------
-- 02_indexes_views.sql : indexes on foreign keys and filters, reporting views
--------------------------------------------------------------------------------

create index vom_vendors_status_ix     on vom_vendors (status);
create index vom_vendors_risk_ix       on vom_vendors (risk_level);
create index vom_contacts_vendor_ix    on vom_vendor_contacts (vendor_id);
create index vom_documents_vendor_ix   on vom_vendor_documents (vendor_id);
create index vom_documents_expiry_ix   on vom_vendor_documents (expires_on, status);
create index vom_steps_vendor_ix       on vom_approval_steps (vendor_id, step_seq);
create index vom_steps_inbox_ix        on vom_approval_steps (approver_role, status);
create index vom_audit_entity_ix       on vom_audit_log (entity_name, entity_id);

-- Vendor list with document health, used by the Vendors report and the dashboard
create or replace view vom_vendor_summary_v as
select v.vendor_id,
       v.vendor_number,
       v.vendor_name,
       v.country_code,
       v.category_code,
       v.status,
       v.risk_score,
       v.risk_level,
       v.primary_email,
       v.created_on,
       v.approved_on,
       (select count(*) from vom_vendor_documents d
         where d.vendor_id = v.vendor_id and d.status = 'VALID')    as valid_docs,
       (select count(*) from vom_vendor_documents d
         where d.vendor_id = v.vendor_id and d.status = 'EXPIRING') as expiring_docs,
       (select count(*) from vom_vendor_documents d
         where d.vendor_id = v.vendor_id and d.status = 'EXPIRED')  as expired_docs
  from vom_vendors v;

-- Approver inbox: the current actionable step for each vendor in review
create or replace view vom_approval_inbox_v as
select s.step_id,
       s.vendor_id,
       v.vendor_name,
       v.risk_level,
       v.risk_score,
       s.step_seq,
       s.approver_role,
       s.created_on as waiting_since,
       round(sysdate - s.created_on, 1) as days_waiting
  from vom_approval_steps s
  join vom_vendors v on v.vendor_id = s.vendor_id
 where s.status = 'PENDING';

-- Documents that need attention in the next 60 days
create or replace view vom_expiring_documents_v as
select d.doc_id,
       d.vendor_id,
       v.vendor_name,
       t.doc_type_name,
       d.expires_on,
       d.status,
       trunc(d.expires_on) - trunc(sysdate) as days_left
  from vom_vendor_documents d
  join vom_vendors v        on v.vendor_id = d.vendor_id
  join vom_document_types t on t.doc_type_code = d.doc_type_code
 where d.expires_on is not null
   and d.expires_on <= sysdate + 60
   and d.status in ('VALID','EXPIRING','EXPIRED');
