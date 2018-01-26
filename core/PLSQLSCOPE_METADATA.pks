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

CREATE OR REPLACE PACKAGE PLSQLSCOPE_METADATA AUTHID CURRENT_USER IS

   FUNCTION init_self RETURN t_object;

   FUNCTION upload_rules RETURN t_scope_rules;

   FUNCTION upload_ignore_list RETURN t_scope_result_rows;

   TYPE t_csv_row IS TABLE OF VARCHAR2(32000);

   FUNCTION get_exclusions_csv_format RETURN t_csv_row
      PIPELINED;

   FUNCTION get_rules_csv_format RETURN t_csv_row
      PIPELINED;

END PLSQLSCOPE_METADATA;
/
