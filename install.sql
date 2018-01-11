set echo off
set verify off
column 1 new_value 1 noprint
column 2 new_value 2 noprint
column 3 new_value 3 noprint
select null as "1", null as "2" , null as "3" from dual where 1=0;
column sep new_value sep noprint
select '--------------------------------------------------------------' as sep from dual;

spool params.sql.tmp

column plscope_user      new_value plscope_user      noprint
column plscope_user_password   new_value plscope_user_password   noprint
column plscope_user_tablespace new_value plscope_user_tablespace noprint


SELECT coalesce('&&1', 'plscope') plscope_user
      ,coalesce('&&2', 'plscope') plscope_user_password
      ,coalesce('&&3',
                (SELECT property_Value
                  FROM   database_properties
                  WHERE  property_name = 'DEFAULT_PERMANENT_TABLESPACE')) plscope_user_tablespace
FROM   dual;


@@create_plscope_owner.sql &&plscope_user &&plscope_user_password &&plscope_user_tablespace
@@installobjects.sql &&plscope_user

exit;
