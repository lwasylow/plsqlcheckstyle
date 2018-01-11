whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

define plscope_user       = &1

Prompt Dropping &plscope_user

BEGIN
   EXECUTE IMMEDIATE 'DROP USER &plscope_user CASCADE';
EXCEPTION WHEN OTHERS THEN
 dbms_output.put_line('User dont exists, skipping');
END;
/

exit;
