set echo off
set verify off
set trimspool on
set feedback off
set linesize 32767
set pagesize 0
set long 200000000
set longchunksize 1000000
set serveroutput on size unlimited format truncated
set arraysize 50
set pagesize 0
set newpage 0

define check_schema = "&1"
define static_files = "&2"
define path_to_files = "&3"

DECLARE
   -- Non-scalar parameters require additional processing 
   i_schemas    varchar2_tab := varchar2_tab(&check_schema);
   i_objects    varchar2_tab := varchar2_tab();
   i_reporter   plssqlscope_api.t_reporter_tab := plssqlscope_api.t_reporter_tab();
   i_reportname plssqlscope_api.t_reporter_rec;
BEGIN
   i_reportname.reporter_name := 'HTML';
   i_reportname.rootpath := '&static_files';
   i_reporter.extend;
   i_reporter(1) := i_reportname;
   i_reportname.reporter_name := 'PMD';
   i_reportname.rootpath := '&path_to_files';
   i_reportname.objecttopath := 'CODE/Stored_Procs/';
   i_reporter.extend;
   i_reporter(2) := i_reportname;
   i_reportname.reporter_name := 'CSVEXCL';
   i_reporter.extend;
   i_reporter(3) := i_reportname;
   -- Call the procedure
   plssqlscope_api.runner(i_schemas => i_schemas, i_objects => i_objects,
                          i_reporter => i_reporter);

END;
/


set termout off

spool checkstyle_result.html
SELECT * FROM TABLE( plssqlscope_api.output_buffer(i_report_id => 'HTML'));
spool off


spool pmd_result.xml
SELECT * FROM TABLE( plssqlscope_api.output_buffer(i_report_id => 'PMD'));
spool off

spool csv_exclusions_candidate.dat
SELECT * FROM TABLE( plssqlscope_api.output_buffer(i_report_id => 'CSVEXCL'));
spool off
exit;