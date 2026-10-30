--------------------------------------------------------------------------------
-- vom_util : current user resolution and audit logging
--------------------------------------------------------------------------------
create or replace package vom_util as

  -- APEX user when called from an APEX session, database user otherwise
  function current_user return varchar2;

  procedure audit (
    p_entity_name in varchar2,
    p_entity_id   in number,
    p_action      in varchar2,
    p_old_value   in varchar2 default null,
    p_new_value   in varchar2 default null,
    p_details     in varchar2 default null
  );

end vom_util;
/

create or replace package body vom_util as

  function current_user return varchar2 is
  begin
    return coalesce(sys_context('APEX$SESSION', 'APP_USER'), sys_context('USERENV', 'SESSION_USER'));
  end current_user;

  procedure audit (
    p_entity_name in varchar2,
    p_entity_id   in number,
    p_action      in varchar2,
    p_old_value   in varchar2 default null,
    p_new_value   in varchar2 default null,
    p_details     in varchar2 default null
  ) is
  begin
    insert into vom_audit_log (entity_name, entity_id, action, old_value, new_value, details, performed_by)
    values (p_entity_name, p_entity_id, p_action, p_old_value, p_new_value,
            substr(p_details, 1, 4000), current_user);
  end audit;

end vom_util;
/
