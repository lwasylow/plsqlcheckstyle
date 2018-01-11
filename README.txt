Usage 

DECLARE
   -- Non-scalar parameters require additional processing 
   i_schemas    varchar2_tab := varchar2_tab('UT_TEST');
   i_objects    varchar2_tab := varchar2_tab();
   i_reporter   plssqlscope_api.t_reporter_tab := plssqlscope_api.t_reporter_tab();
   i_reportname plssqlscope_api.t_reporter_rec;
BEGIN
   i_reportname.reporter_name := 'HTML';
   i_reporter.extend;
   i_reporter(1) := i_reportname;
   i_reportname.reporter_name := 'PMD';
   i_reporter.extend;
   i_reporter(2) := i_reportname;
   -- Call the procedure
   plssqlscope_api.runner(i_schemas => i_schemas, i_objects => i_objects,
                          i_reporter => i_reporter);

END;
/

SELECT * FROM TABLE( plssqlscope_api.output_buffer(i_report_id => 'HTML'));

SELECT * FROM TABLE( plssqlscope_api.output_buffer(i_report_id => 'PMD'));

