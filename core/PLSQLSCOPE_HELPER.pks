/*
  Copyright 2018 Lukasz Wasylow   

 Licensed under the Apache License, Version 2.0 (the "License"):
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
 */  

CREATE OR REPLACE PACKAGE PLSQLSCOPE_HELPER IS

   -- Author  : LUW07
   -- Created : 25/05/2017 16:29:02
   -- Purpose : Helper of static code analysis

   FUNCTION init_self RETURN t_object;

   FUNCTION table_to_clob(i_text_table varchar2_tab
                         ,i_delimiter  IN VARCHAR2 := chr(10)) RETURN CLOB;

   PROCEDURE recompile_with_scope_objects(i_run_paths IN t_objects);

   PROCEDURE recompile_with_scope_schema(i_schema IN VARCHAR2);

   FUNCTION get_html_report(i_sourcedata IN t_scope_result_rows
                           ,i_root_path  IN VARCHAR2 DEFAULT 'libs') RETURN CLOB;

   FUNCTION get_console_report(i_sourcedata IN t_scope_result_rows) RETURN CLOB;

   FUNCTION get_checkstyle_report(i_sourcedata IN t_scope_result_rows
                                 ,i_root_path  IN VARCHAR2) RETURN CLOB;

   FUNCTION get_pmd_report(i_sourcedata  IN t_scope_result_rows
                          ,i_root_path   IN VARCHAR2
                          ,i_object_path IN VARCHAR2) RETURN CLOB;

   FUNCTION get_exclusions_csv_report(i_sourcedata IN t_scope_result_rows) RETURN CLOB;

   PROCEDURE print_clob_by_line(i_data IN CLOB);

END PLSQLSCOPE_HELPER;
/
