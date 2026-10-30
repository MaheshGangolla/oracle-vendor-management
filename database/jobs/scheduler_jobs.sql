--------------------------------------------------------------------------------
-- scheduler_jobs.sql : daily document-expiry processing
--   06:00 every day: refresh document statuses and send renewal reminders
--------------------------------------------------------------------------------
begin
  dbms_scheduler.create_job(
    job_name        => 'VOM_DAILY_DOCUMENT_EXPIRY',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'begin vom_notify.send_expiry_reminders; commit; end;',
    start_date      => systimestamp,
    repeat_interval => 'FREQ=DAILY;BYHOUR=6;BYMINUTE=0;BYSECOND=0',
    enabled         => true,
    comments        => 'Vendor Onboarding: refresh document expiry status and send renewal reminders');
end;
/
