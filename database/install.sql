--------------------------------------------------------------------------------
-- install.sql : installs the Vendor Onboarding & Compliance Management schema
--
-- Run as the APEX workspace parsing schema from the repository root:
--   sql <user>@<connect>  @database/install.sql          (SQLcl)
--   or SQL Workshop > SQL Scripts in APEX (run each file in this order)
--------------------------------------------------------------------------------
whenever sqlerror exit failure rollback
set define off

prompt == Tables
@@ddl/01_tables.sql
prompt == Indexes and views
@@ddl/02_indexes_views.sql

prompt == Packages
@@packages/vom_util.sql
@@packages/vom_security.sql
@@packages/vom_document_mgr.sql
@@packages/vom_notify.sql
@@packages/vom_risk_engine.sql
@@packages/vom_workflow.sql
@@packages/vom_vendor_api.sql

prompt == Reference data
@@data/01_reference_data.sql

prompt == Scheduler job
@@jobs/scheduler_jobs.sql

prompt == Invalid objects (should return no rows)
select object_name, object_type from user_objects where status = 'INVALID' and object_name like 'VOM%';

prompt == Done. Optional: @@data/02_sample_data.sql for demo data, @../ords/vendor_api_module.sql for REST.
