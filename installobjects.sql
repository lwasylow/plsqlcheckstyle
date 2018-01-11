prompt Installing PLSSQL Checkstyle Framework

set serveroutput on size unlimited

define plscope_owner = &1

whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

alter session set current_schema = &&plscope_owner;

set define off

prompt Deploying Types

--common utilities
@@core/types/VARCHAR2_TAB.tps
@@core/types/T_OBJECT.tps
@@core/types/T_OBJECTS.tps
@@core/types/T_SCOPE_RESULT_ROW.tps
@@core/types/T_SCOPE_RESULT_ROWS.tps
@@core/types/T_SCOPE_ROW.tps
@@core/types/T_SCOPE_ROWS.tps
@@core/types/T_SCOPE_RULE.tps
@@core/types/T_SCOPE_RULES.tps

prompt Deploying Tables

@@core/create_gtt_scope_rows.sql
@@core/create_gtt_validation_res.sql
@@core/create_ruletable.sql
@@core/create_exclusion_table.sql

prompt Deploying Packages

@@core/PLSQLSCOPE_METADATA.pks
@@core/PLSQLSCOPE_METADATA.pkb
@@core/PLSQLSCOPE_HELPER.pks
@@core/PLSQLSCOPE_HELPER.pkb
@@core/PLSSQLSCOPE_API.pks
@@core/PLSSQLSCOPE_API.pkb

set linesize 200
set define &
column text format a100
column error_count noprint new_value error_count
prompt Validating installation
select name, type, sequence, line, position, text, count(1) over() error_count
  from all_errors
 where owner = upper('&&plscope_owner')
   and name not like 'BIN$%'  --not recycled
   and (name = 'UT' or name like 'UT\_%' escape '\')
   -- errors only. ignore warnings
   and attribute = 'ERROR'
/

begin
  if to_number('&&error_count') > 0 then
    raise_application_error(-20000, 'Not all sources were successfully installed.');
  end if;
end;
/
