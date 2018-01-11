whenever sqlerror exit failure rollback
whenever oserror exit failure rollback
set echo off
set feedback off
set heading off
set verify off

define plscope_user       = &1

drop user &plscope_user cascade;

exit;