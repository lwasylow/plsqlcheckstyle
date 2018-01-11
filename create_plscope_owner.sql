whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

define plscope_user       = &1
define plscope_user_password   = &2
define plscope_user_tablespace = &3

Prompt Creating User &plscope_user

create user &plscope_user identified by &plscope_user_password default tablespace &plscope_user_tablespace quota unlimited on &plscope_user_tablespace;

Promp Apply Grants To User &plscope_user

grant create session, create sequence, create procedure, create type, create table, create view, create synonym to &plscope_user;
grant alter any procedure to &plscope_user;
grant create any procedure to &plscope_user;
grant alter session to &plscope_user;
grant select on dba_identifiers to &plscope_user;
grant select on dba_errors to &plscope_user;
grant select on dba_source to &plscope_user;