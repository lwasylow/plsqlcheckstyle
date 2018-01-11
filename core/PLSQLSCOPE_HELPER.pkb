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

CREATE OR REPLACE PACKAGE BODY PLSQLSCOPE_HELPER IS

   C_ENABLE_IDENTIFIERS  CONSTANT VARCHAR2(255) := 'ALTER SESSION SET PLSCOPE_SETTINGS=''IDENTIFIERS:ALL''';
   C_ENABLE_WARNINGS     CONSTANT VARCHAR2(255) := 'ALTER SESSION SET PLSQL_WARNINGS=''ENABLE:ALL''';
   C_DISABLE_IDENTIFIERS CONSTANT VARCHAR2(255) := 'ALTER SESSION SET PLSQL_WARNINGS=''DISABLE:ALL''';
   C_DISABLE_WARNINGS    CONSTANT VARCHAR2(255) := 'ALTER SESSION SET PLSCOPE_SETTINGS=''IDENTIFIERS:NONE''';

   FUNCTION init_self RETURN t_object IS
      l_schema   VARCHAR2(30) := sys_context('userenv', 'current_schema');
      l_object   VARCHAR2(30) := $$PLSQL_UNIT;
      l_fullname t_object;
   BEGIN
      l_fullname := t_object(l_object, l_schema, NULL);
      RETURN l_fullname;
   END init_self;

   PROCEDURE append_to_clob(i_src_clob IN OUT NOCOPY CLOB
                           ,i_new_data CLOB) IS
   BEGIN
      IF i_new_data IS NOT NULL AND dbms_lob.getlength(i_new_data) > 0 THEN
         IF i_src_clob IS NULL THEN
            dbms_lob.createtemporary(i_src_clob, TRUE);
         END IF;
         dbms_lob.append(i_src_clob, i_new_data);
      END IF;
   END;

   PROCEDURE append_to_clob(i_src_clob IN OUT NOCOPY CLOB
                           ,i_new_data VARCHAR2) IS
   BEGIN
      IF i_new_data IS NOT NULL THEN
         IF i_src_clob IS NULL THEN
            dbms_lob.createtemporary(i_src_clob, TRUE);
         END IF;
         dbms_lob.writeappend(i_src_clob, length(i_new_data), i_new_data);
      END IF;
   END;

   FUNCTION table_to_clob(i_text_table varchar2_tab
                         ,i_delimiter  IN VARCHAR2 := chr(10)) RETURN CLOB IS
      l_result          CLOB;
      l_text_table_rows INTEGER := coalesce(cardinality(i_text_table), 0);
   BEGIN
      FOR i IN 1 .. l_text_table_rows
      LOOP
         IF i < l_text_table_rows THEN
            append_to_clob(l_result, i_text_table(i) || i_delimiter);
         ELSE
            append_to_clob(l_result, i_text_table(i));
         END IF;
      END LOOP;
      RETURN l_result;
   END;

   FUNCTION string_to_table(a_string                 VARCHAR2
                           ,a_delimiter              VARCHAR2 := chr(10)
                           ,a_skip_leading_delimiter VARCHAR2 := 'N') RETURN varchar2_tab IS
      l_offset                 INTEGER := 1;
      l_delimiter_position     INTEGER;
      l_skip_leading_delimiter BOOLEAN := coalesce(a_skip_leading_delimiter = 'Y', FALSE);
      l_result                 varchar2_tab := varchar2_tab();
   BEGIN
      IF a_string IS NULL THEN
         RETURN l_result;
      END IF;
      IF a_delimiter IS NULL THEN
         RETURN varchar2_tab(a_string);
      END IF;
   
      LOOP
         l_delimiter_position := instr(a_string, a_delimiter, l_offset);
         IF NOT (l_delimiter_position = 1 AND l_skip_leading_delimiter) THEN
            l_result.extend;
            IF l_delimiter_position > 0 THEN
               l_result(l_result.last) := substr(a_string, l_offset,
                                                 l_delimiter_position - l_offset);
            ELSE
               l_result(l_result.last) := substr(a_string, l_offset);
            END IF;
         END IF;
         EXIT WHEN l_delimiter_position = 0;
         l_offset := l_delimiter_position + 1;
      END LOOP;
      RETURN l_result;
   END;

   PROCEDURE recompile_with_scope_schema(i_schema IN VARCHAR2) IS
   
   BEGIN
      EXECUTE IMMEDIATE C_ENABLE_IDENTIFIERS;
      EXECUTE IMMEDIATE C_ENABLE_WARNINGS;
   
      dbms_utility.compile_schema(schema => i_schema,compile_all => TRUE);
   
      EXECUTE IMMEDIATE C_DISABLE_IDENTIFIERS;
      EXECUTE IMMEDIATE C_DISABLE_WARNINGS;
   
   END recompile_with_scope_schema;

   PROCEDURE recompile_with_scope_objects(i_run_paths IN t_objects) IS
      l_sql VARCHAR2(4000);
   BEGIN
      EXECUTE IMMEDIATE C_ENABLE_IDENTIFIERS;
      EXECUTE IMMEDIATE C_ENABLE_WARNINGS;
   
      FOR listofobjects IN 1 .. i_run_paths.COUNT
      LOOP
         BEGIN
            l_sql := 'ALTER ' || CASE
                        WHEN i_run_paths(listofobjects).objecttype IN ('PACKAGE BODY') THEN
                         'PACKAGE'
                        ELSE
                         i_run_paths(listofobjects).objecttype
                     END || ' ' || i_run_paths(listofobjects).objectowner || '.' || i_run_paths(listofobjects)
                    .objectname || ' COMPILE ' || CASE
                        WHEN i_run_paths(listofobjects).objecttype IN ('PACKAGE BODY') THEN
                         'BODY'
                        ELSE
                         NULL
                     END;
            EXECUTE IMMEDIATE l_sql;
         EXCEPTION
            WHEN OTHERS THEN
               RAISE;
               --Rethink what to do when compilaton fails.
         END;
      END LOOP;
   
      EXECUTE IMMEDIATE C_DISABLE_IDENTIFIERS;
      EXECUTE IMMEDIATE C_DISABLE_WARNINGS;
   
   END recompile_with_scope_objects;

   FUNCTION clob_to_table(i_clob       IN CLOB
                         ,i_max_amount IN INTEGER := 32767
                         ,i_delimiter  IN VARCHAR2 := chr(10)) RETURN varchar2_tab IS
      l_offset                 INTEGER := 1;
      l_length                 INTEGER := dbms_lob.getlength(i_clob);
      l_amount                 INTEGER;
      l_buffer                 VARCHAR2(32767);
      l_last_line              VARCHAR2(32767);
      l_string_results         varchar2_tab;
      l_results                varchar2_tab := varchar2_tab();
      l_has_last_line          BOOLEAN;
      l_skip_leading_delimiter VARCHAR2(1) := 'N';
   BEGIN
      WHILE l_offset <= l_length
      LOOP
         l_amount := i_max_amount - coalesce(length(l_last_line), 0);
         dbms_lob.read(i_clob, l_amount, l_offset, l_buffer);
         l_offset := l_offset + l_amount;
      
         l_string_results := string_to_table(l_last_line || l_buffer, i_delimiter,
                                             l_skip_leading_delimiter);
         FOR i IN 1 .. l_string_results.count
         LOOP
            --if a split of lines was not done or not at the last line
            IF l_string_results.count = 1 OR i < l_string_results.count THEN
               l_results.extend;
               l_results(l_results.last) := l_string_results(i);
            END IF;
         END LOOP;
      
         --check if we need to append the last line to the next element
         IF l_string_results.count = 1 THEN
            l_has_last_line := FALSE;
            l_last_line     := NULL;
         ELSIF l_string_results.count > 1 THEN
            l_has_last_line := TRUE;
            l_last_line     := l_string_results(l_string_results.count);
         END IF;
      
         l_skip_leading_delimiter := 'Y';
      END LOOP;
      IF l_has_last_line THEN
         l_results.extend;
         l_results(l_results.last) := l_last_line;
      END IF;
      RETURN l_results;
   END;

   FUNCTION get_html_report(i_sourcedata IN t_scope_result_rows
                           ,i_root_path  IN VARCHAR2 DEFAULT 'libs') RETURN CLOB IS
      l_report    CLOB;
      l_file_part VARCHAR2(32767);
   BEGIN
      dbms_lob.createtemporary(l_report, TRUE);
      l_file_part := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
           "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
	<title>Oracle Checkstyle Report</title>
	<link title="Style" type="text/css" rel="stylesheet" href="' ||
                     i_root_path || 'css/main.css"/>
	<script src="' || i_root_path || 'scripts/filter.js"></script>
	</head>
  <body><h5>Oracle Checkstyle Report</h5>
	<div class="separator">&#160;</div>	
	<input type="search" class="light-table-filter" data-table="report" placeholder="Filter" />
	<div class="separator">&#160;</div>	
	<table class="report">
	 <thead>
    <tr>
     <td class="heading">Schema Name</td>
     <td class="heading">Object Name</td>
     <td class="heading">Object Type</td>
     <td class="heading">Rule Name</td>
     <td class="heading">Identifier</td>
     <td class="heading">Violation Description</td>
     <td class="heading">Line</td>
     <td class="heading">Source Text</td>
    </tr>
   </thead>
	 <tbody>	' || CHR(10);
      dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
   
      FOR data IN (SELECT *
                   FROM   TABLE(i_sourcedata))
      LOOP
         l_file_part := '<tr><td>' || data.object_owner || '</td><td>' ||
                        data.object_name || '</td><td>' || data.object_type ||
                        '</td><td>' || data.rule_name || '</td><td>' || data.identifier ||
                        '</td><td>' || data.rule_desc || '</td><td>' || data.line ||
                        '</td><td><code>' || data.source || '</code></td></tr>' ||
                        CHR(10);
      
         dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
      END LOOP;
   
      l_file_part := '</tbody></table>	<div class="separator">&#160;</div>
  <div class="separator">&nbsp;</div>
  <div class="footer">Report generated on ' ||
                     TO_CHAR(SYSDATE, 'DD/MM/RRRR HH24:MI:SS') || '</div></body></html>' ||
                     CHR(10);
      dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
   
      RETURN l_report;
   END get_html_report;

   FUNCTION get_checkstyle_report(i_sourcedata IN t_scope_result_rows
                                 ,i_root_path  IN VARCHAR2) RETURN CLOB IS
      l_report    CLOB;
      l_file_part VARCHAR2(32767);
   BEGIN
   
      dbms_lob.createtemporary(l_report, TRUE);
      l_file_part := '<?xml version="1.0" encoding="UTF-8"?>
                      <checkstyle version="5.7">';
   
      dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
   
      FOR object_list IN (SELECT DISTINCT object_owner
                                         ,object_name
                                         ,object_type
                          FROM   TABLE(i_sourcedata))
      LOOP
         l_file_part := '<file name="' || i_root_path || '/' || object_list.object_owner || '.' ||
                        object_list.object_name || ' : ' || object_list.object_type ||
                        '"> ';
      
         dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
      
         FOR object_errors IN (SELECT *
                               FROM   TABLE(i_sourcedata)
                               WHERE  object_owner = object_list.object_owner
                               AND    object_name = object_list.object_name
                               AND    object_type = object_list.object_type)
         LOOP
            l_file_part := '<error line="' || object_errors.line || '" message="' ||
                           object_errors.identifier || '" severity="error" source="' ||
                           object_errors.source || '" category="' ||
                           object_errors.rule_category || '" rule="' ||
                           object_errors.rule_desc || '"/>' || CHR(10);
         
            dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
         END LOOP;
      
         l_file_part := '</file>' || CHR(10);
      
         dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
      
      END LOOP;
   
      l_file_part := '</checkstyle>';
      dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
   
      RETURN l_report;
   END get_checkstyle_report;

   FUNCTION get_pmd_report(i_sourcedata  IN t_scope_result_rows
                          ,i_root_path   IN VARCHAR2
                          ,i_object_path IN VARCHAR2) RETURN CLOB IS
      l_report    CLOB;
      l_file_part VARCHAR2(32767);
   BEGIN
      dbms_lob.createtemporary(l_report, TRUE);
      l_file_part := '<pmd timestamp="' || TO_CHAR(SYSDATE, 'RRRR-MM-DD HH24:MI:SS') ||
                     '" version="5.7.0">' || CHR(10);
      dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
   
      FOR data IN (SELECT *
                   FROM   TABLE(i_sourcedata))
      LOOP
      
         l_file_part := '<file name="' || i_root_path || data.object_owner || '/' ||
                        i_object_path || data.object_name || CASE data.object_type
                           WHEN 'PACKAGE' THEN
                            '.pks'
                           WHEN 'PACKAGE BODY' THEN
                            '.pkb'
                           ELSE
                            '.sql'
                        END || '">
         <violation begincolumn="1" beginline="' || data.line ||
                        '" endcolumn="1" endline="' || data.line ||
                        '" priority="2" rule="' || data.rule_name || '"
         ruleset="' || data.rule_category || '">' ||
                        data.rule_desc || ' (' || data.identifier || ') : ' ||
                        data.source || '
         </violation></file>' || CHR(10);
         dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
      END LOOP;
   
      l_file_part := '</pmd>' || CHR(10);
      dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
   
      RETURN l_report;
   END get_pmd_report;

   FUNCTION get_console_report(i_sourcedata IN t_scope_result_rows) RETURN CLOB IS
      l_report    CLOB;
      l_file_part VARCHAR2(32767);
   
   BEGIN
      dbms_lob.createtemporary(l_report, TRUE);
   
      IF i_sourcedata IS NOT NULL THEN
      
         FOR summary IN (SELECT COUNT(1) total
                               ,object_owner
                         FROM   TABLE(i_sourcedata)
                         GROUP  BY object_owner
                         ORDER  BY object_owner)
         LOOP
            l_file_part := 'For Schema: ' || summary.object_owner || ' there are :' ||
                           summary.total || ' checkstyle errors' || CHR(10);
         
            dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
         END LOOP;
      
         l_file_part := CHR(10) || 'Please see details:' || CHR(10);
         dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
      
         FOR data IN (SELECT *
                      FROM   TABLE(i_sourcedata)
                      ORDER  BY object_owner
                               ,object_name
                               ,object_type
                               ,line)
         LOOP
            l_file_part := 'Object Owner : ' || data.object_owner || CHR(10) ||
                           'Object Name : ' || data.object_name || CHR(10) ||
                           'Object Type : ' || data.object_type || CHR(10) ||
                           'Identifier : ' || data.identifier || CHR(10) ||
                           'Line of Code : ' || data.line || CHR(10) || 'Rule Name : ' ||
                           data.rule_name || CHR(10) || 'Rule Desciption : ' ||
                           data.rule_desc || CHR(10) || CHR(10);
         
            dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
         END LOOP;
      ELSE
         l_file_part := 'No issues have been found for given checkstyle run';
      
         dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
      
      END IF;
   
      RETURN l_report;
   END get_console_report;

   FUNCTION get_exclusions_csv_report(i_sourcedata IN t_scope_result_rows) RETURN CLOB IS
      l_report    CLOB;
      l_file_part VARCHAR2(32767);
   
   BEGIN
      dbms_lob.createtemporary(l_report, TRUE);
   
      IF i_sourcedata IS NOT NULL THEN
      
         FOR data IN (SELECT *
                      FROM   TABLE(i_sourcedata))
         LOOP
            l_file_part := '"' || data.rule_name || '","' || data.rule_category || '","' ||
                           data.identifier || '","' || data.line || '","' ||
                           data.object_type || '","' || data.object_name || '","' ||
                           data.object_owner || '"' || CHR(10);
         
            dbms_lob.writeappend(l_report, length(l_file_part), l_file_part);
         END LOOP;
      
      END IF;
   
      RETURN l_report;
   
   END get_exclusions_csv_report;

   PROCEDURE print_clob_by_line(i_data IN CLOB) IS
      l_lines varchar2_tab;
   BEGIN
      l_lines := clob_to_table(i_data);
      FOR i IN 1 .. l_lines.count
      LOOP
         dbms_output.put_line(l_lines(i) || chr(10));
      END LOOP;
   END print_clob_by_line;

END PLSQLSCOPE_HELPER;
/
