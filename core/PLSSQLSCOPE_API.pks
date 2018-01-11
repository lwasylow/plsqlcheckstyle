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

CREATE OR REPLACE PACKAGE PLSSQLSCOPE_API IS

   -- Author  : LUW07
   -- Created : 25/05/2017 16:29:02
   -- Purpose : Static code analysis

   TYPE t_reporter_rec IS RECORD(
       reporter_name VARCHAR2(10) DEFAULT 'CONSOLE'
      ,rootpath   VARCHAR2(500) DEFAULT NULL
      ,objecttopath   VARCHAR2(500) DEFAULT NULL);

   TYPE t_reporter_tab IS TABLE OF t_reporter_rec;

   PROCEDURE print_report(i_report_data IN CLOB);

   PROCEDURE print_report(i_report_id IN VARCHAR2);

   FUNCTION run(i_schema IN VARCHAR2 DEFAULT NULL) RETURN t_scope_result_rows
      PIPELINED;

   PROCEDURE run(i_schema   IN VARCHAR2 DEFAULT NULL
                ,i_reporter IN t_reporter_rec DEFAULT NULL);

   FUNCTION run(i_schema IN VARCHAR2 DEFAULT NULL
               ,i_object IN VARCHAR2) RETURN t_scope_result_rows
      PIPELINED;

   PROCEDURE run(i_schema   IN VARCHAR2 DEFAULT NULL
                ,i_object   IN VARCHAR2
                ,i_reporter IN t_reporter_rec DEFAULT NULL);

   PROCEDURE run(i_schemas  IN varchar2_tab
                ,i_reporter IN t_reporter_rec DEFAULT NULL);

   PROCEDURE run(i_objects  IN varchar2_tab
                ,i_reporter IN t_reporter_rec DEFAULT NULL);

   PROCEDURE run(i_schema   IN VARCHAR2
                ,i_objects  IN varchar2_tab
                ,i_reporter IN t_reporter_rec DEFAULT NULL);

   PROCEDURE run(i_object_list IN t_objects
                ,i_reporter    IN t_reporter_rec DEFAULT NULL);

   PROCEDURE runner(i_schemas  IN varchar2_tab
                   ,i_objects  IN varchar2_tab
                   ,i_reporter IN t_reporter_tab);

   FUNCTION output_buffer(i_report_id IN VARCHAR2) RETURN varchar2_tab PIPELINED;

END PLSSQLSCOPE_API;
/
