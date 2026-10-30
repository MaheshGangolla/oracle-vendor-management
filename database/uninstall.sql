--------------------------------------------------------------------------------
-- uninstall.sql : removes every VOM object (data is lost)
--------------------------------------------------------------------------------
begin
  dbms_scheduler.drop_job('VOM_DAILY_DOCUMENT_EXPIRY', force => true);
exception when others then null;
end;
/

begin
  ords.delete_module(p_module_name => 'vom.vendor.api.v1');
  commit;
exception when others then null;
end;
/

drop package vom_vendor_api;
drop package vom_workflow;
drop package vom_risk_engine;
drop package vom_notify;
drop package vom_document_mgr;
drop package vom_security;
drop package vom_util;

drop view vom_expiring_documents_v;
drop view vom_approval_inbox_v;
drop view vom_vendor_summary_v;

drop table vom_audit_log          purge;
drop table vom_approval_steps     purge;
drop table vom_approval_rules     purge;
drop table vom_vendor_risk        purge;
drop table vom_risk_factors       purge;
drop table vom_vendor_documents   purge;
drop table vom_document_types     purge;
drop table vom_vendor_contacts    purge;
drop table vom_vendors            purge;
drop table vom_user_roles         purge;
drop table vom_lookups            purge;
