--------------------------------------------------------------------------------
-- vom_security : role checks used by APEX authorization schemes
--   Authorization scheme type "PL/SQL Function Returning Boolean":
--     return vom_security.has_role('PROCUREMENT');
--------------------------------------------------------------------------------
create or replace package vom_security as

  function has_role (p_role_code in varchar2, p_username in varchar2 default null) return boolean;

  -- 'Y'/'N' variant for use in SQL (report columns, conditions)
  function has_role_yn (p_role_code in varchar2, p_username in varchar2 default null) return varchar2;

  procedure assert_role (p_role_code in varchar2);

end vom_security;
/

create or replace package body vom_security as

  function has_role (p_role_code in varchar2, p_username in varchar2 default null) return boolean is
    l_count pls_integer;
  begin
    select count(*)
      into l_count
      from vom_user_roles
     where upper(username) = upper(coalesce(p_username, vom_util.current_user))
       and role_code in (p_role_code, 'ADMIN');
    return l_count > 0;
  end has_role;

  function has_role_yn (p_role_code in varchar2, p_username in varchar2 default null) return varchar2 is
  begin
    return case when has_role(p_role_code, p_username) then 'Y' else 'N' end;
  end has_role_yn;

  procedure assert_role (p_role_code in varchar2) is
  begin
    if not has_role(p_role_code) then
      raise_application_error(-20100, 'You are not authorized to perform this action (role ' || p_role_code || ' required).');
    end if;
  end assert_role;

end vom_security;
/
