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

CREATE OR REPLACE PACKAGE BODY PLSSQLSCOPE_API IS

   g_current_schema VARCHAR2(30) := sys_context('userenv', 'current_schema');

   FUNCTION init_self RETURN t_object IS
      l_schema   VARCHAR2(30) := sys_context('userenv', 'current_schema');
      l_object   VARCHAR2(30) := $$PLSQL_UNIT;
      l_fullname t_object;
   BEGIN
      l_fullname := t_object(l_object, l_schema, NULL);
      RETURN l_fullname;
   END init_self;

   PROCEDURE set_module(i_modulename IN VARCHAR2 DEFAULT 'PLSCOPE') IS
   
   BEGIN
      dbms_application_info.set_module(module_name => i_modulename, action_name => NULL);
   END set_module;

   FUNCTION exclude_framework_objects RETURN t_objects IS
      l_excluded_objects t_objects := t_objects();
   BEGIN
      dbms_application_info.set_action(action_name => 'Exclude Errors');
   
      l_excluded_objects.extend;
      l_excluded_objects(l_excluded_objects.LAST) := init_self;
      l_excluded_objects.extend;
      l_excluded_objects(l_excluded_objects.LAST) := plsqlscope_metadata.init_self;
      l_excluded_objects.extend;
      l_excluded_objects(l_excluded_objects.LAST) := plsqlscope_helper.init_self;
   
      RETURN l_excluded_objects;
   END;
   --Return list of all objects to be tested
   FUNCTION get_object_list(i_schemas IN varchar2_tab
                           ,i_objects IN varchar2_tab) RETURN t_objects IS
      l_objectlist    t_objects;
      l_excluded_list t_objects := exclude_framework_objects;
   
      CURSOR c_schemas_object IS
         SELECT t_object(o.object_name, o.owner, o.object_type)
         FROM   all_objects o
         WHERE  o.owner IN (SELECT *
                            FROM   TABLE(i_schemas))
         AND    o.object_name IN (SELECT *
                                  FROM   TABLE(i_objects))
         AND    o.object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE BODY', 'PACKAGE')
         AND    o.generated <> 'Y'
         AND    NOT EXISTS
          (SELECT 1
                 FROM   TABLE(l_excluded_list) t
                 WHERE  o.object_name = NVL(t.objectname, o.object_name)
                 AND    o.owner = NVL(t.objectowner, o.owner)
                 AND    o.object_type = NVL(t.objecttype, o.object_type))
         ORDER  BY o.owner
                  ,o.object_name
                  ,CASE
                      WHEN o.object_type IN ('PACKAGE') THEN
                       1
                      ELSE
                       2
                   END;
   
      CURSOR c_schemas IS
         SELECT t_object(o.object_name, o.owner, o.object_type)
         FROM   all_objects o
         WHERE  o.owner IN (SELECT *
                            FROM   TABLE(i_schemas))
         AND    o.object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE BODY', 'PACKAGE')
         AND    o.generated <> 'Y'
         AND    NOT EXISTS
          (SELECT 1
                 FROM   TABLE(l_excluded_list) t
                 WHERE  o.object_name = NVL(t.objectname, o.object_name)
                 AND    o.owner = NVL(t.objectowner, o.owner)
                 AND    o.object_type = NVL(t.objecttype, o.object_type))
         ORDER  BY o.owner
                  ,o.object_name
                  ,CASE
                      WHEN o.object_type IN ('PACKAGE') THEN
                       1
                      ELSE
                       2
                   END;
   
   BEGIN
      dbms_application_info.set_action(action_name => 'Gather Object List');
   
      IF i_objects.COUNT = 0 THEN
         OPEN c_schemas;
         FETCH c_schemas BULK COLLECT
            INTO l_objectlist;
         CLOSE c_schemas;
      ELSE
         OPEN c_schemas_object;
         FETCH c_schemas_object BULK COLLECT
            INTO l_objectlist;
         CLOSE c_schemas_object;
      END IF;
      RETURN l_objectlist;
   END get_object_list;

   PROCEDURE gather_identifiers(i_path IN t_objects) IS
   BEGIN
      --DELETE FROM gtt_scope_rows;
      dbms_application_info.set_action(action_name => 'Gather Identifiers to analysis');
   
      INSERT INTO gtt_scope_rows
         WITH globalsection AS
          (SELECT MIN(line) end_line
                 ,object_name
                 ,owner
           FROM   dba_identifiers
                 ,TABLE(i_path) p
           WHERE  object_type = 'PACKAGE BODY'
           AND    TYPE IN ('PROCEDURE', 'FUNCTION')
           AND    usage != 'CALL'
           AND    owner = p.objectowner
           AND    object_name = p.objectname
           AND    object_type = p.objecttype
           GROUP  BY object_name
                    ,owner),
         identifiers AS
          (SELECT i.name
                 ,i.type
                 ,i.usage
                 ,s.line
                 ,i.object_type
                 ,i.object_name
                 ,REPLACE(s.text, chr(10)) SOURCE
                 ,i.owner
                 ,'N' tobeignored
                 ,id.type context_type
           FROM   dba_identifiers i
           JOIN   TABLE(i_path) p
           ON     (p.objectname = i.object_name AND p.objecttype = i.object_type AND
                  p.objectowner = i.owner)
           JOIN   dba_source s
           ON     (s.name = i.object_name AND s.type = i.object_type AND s.line = i.line AND
                  s.owner = i.owner)
           LEFT   OUTER JOIN dba_identifiers id
           ON     (id.object_name = i.object_name AND id.object_type = i.object_type AND
                  id.owner = i.owner AND id.usage_id = i.usage_context_id)
           WHERE  i.USAGE = 'DECLARATION')
         SELECT NAME
               ,TYPE
               ,usage
               ,line
               ,object_type
               ,object_name
               ,SOURCE
               ,owner
               ,tobeignored
               ,context_type
               ,end_line
               ,CASE
                   WHEN LINE < END_LINE THEN
                    'GLOBAL'
                   WHEN LINE > END_LINE THEN
                    'LOCAL'
                   ELSE
                    NULL
                END
         FROM   (SELECT i.name
                       ,i.type
                       ,i.usage
                       ,i.line
                       ,i.object_type
                       ,i.object_name
                       ,i.SOURCE
                       ,i.owner
                       ,i.tobeignored
                       ,i.context_type
                       ,g.end_line
                 FROM   identifiers i
                 LEFT   OUTER JOIN globalsection g
                 ON     (i.owner = g.owner AND i.object_name = g.object_name)
                 UNION ALL
                 SELECT TO_CHAR(message_number)
                       ,CASE
                           WHEN message_number BETWEEN 5000 AND 5999 THEN
                            'PLWARNINGS_SEVERE'
                           WHEN message_number BETWEEN 6000 AND 6249 THEN
                            'PLWARNINGS_INFO'
                           WHEN message_number BETWEEN 7000 AND 7249 THEN
                            'PLWARNINGS_PERFORMANCE'
                        END rulename
                       ,attribute
                       ,line
                       ,TYPE
                       ,NAME
                       ,REPLACE(text, chr(10)) SOURCE
                       ,owner
                       ,'N' tobeignored
                       ,NULL context_type
                       ,NULL end_line
                 FROM   dba_errors e
                       ,TABLE(i_path) p
                 WHERE  e.owner = p.objectowner
                 AND    e.name = p.objectname
                 AND    e.type = p.objecttype);
   
   END gather_identifiers;

   FUNCTION add_sql_conditions(i_rule_row IN t_scope_rule) RETURN VARCHAR2 IS
      l_conditon_sql VARCHAR2(4000);
   
   BEGIN
      dbms_application_info.set_action(action_name => 'Add SQL Conditions');
   
      IF i_rule_row.identifierusage IS NOT NULL THEN
         l_conditon_sql := l_conditon_sql || CASE
                              WHEN l_conditon_sql IS NULL THEN
                               NULL
                              ELSE
                               ' AND '
                           END || 's.usage = ''' || i_rule_row.identifierusage || '''';
      END IF;
   
      IF i_rule_row.identifiertype IS NOT NULL THEN
         l_conditon_sql := l_conditon_sql || CASE
                              WHEN l_conditon_sql IS NULL THEN
                               NULL
                              ELSE
                               ' AND '
                           END || 's.type =''' || i_rule_row.identifiertype || '''';
      END IF;
   
      IF i_rule_row.identifierplacement IS NOT NULL THEN
         l_conditon_sql := l_conditon_sql || CASE
                              WHEN l_conditon_sql IS NULL THEN
                               NULL
                              ELSE
                               ' AND '
                           END || 's.placement = ''' || i_rule_row.identifierplacement || '''';
      END IF;
   
      IF i_rule_row.ruleregex IS NOT NULL THEN
         l_conditon_sql := l_conditon_sql || CASE
                              WHEN l_conditon_sql IS NULL THEN
                               NULL
                              ELSE
                               ' AND '
                           END || i_rule_row.ruleregex;
      END IF;
   
      RETURN l_conditon_sql;
   
   END add_sql_conditions;

   PROCEDURE apply_rules(o_result_set OUT NOCOPY t_scope_result_rows) AS
      l_rules             t_scope_rules := plsqlscope_metadata.upload_rules;
      l_tmp_resultset     t_scope_result_rows := t_scope_result_rows();
      l_result_set        t_scope_result_rows := t_scope_result_rows();
      l_sql               VARCHAR2(4000);
      l_sql_base_template VARCHAR2(4000) := 'SELECT t_scope_result_row(owner,object_name,object_type,''#RULENAME#'',name,''#RULEDESC#'',''#CATEGORY#'',line,source) FROM  gtt_scope_rows s WHERE ';
      l_sql_base          VARCHAR2(4000);
      l_cnt               NUMBER;
      l_handle            INTEGER;
   BEGIN
      dbms_application_info.set_action(action_name => 'Apply Checkstyle Rules');
   
      FOR rulelist IN 1 .. l_rules.COUNT
      LOOP
         l_sql_base := l_sql_base_template;
         l_sql_base := REPLACE(l_sql_base, '#RULENAME#', l_rules(rulelist).rulename);
         l_sql_base := REPLACE(l_sql_base, '#RULEDESC#', l_rules(rulelist).ruledescription);
         l_sql_base := REPLACE(l_sql_base, '#CATEGORY#', l_rules(rulelist).category);
      
         l_sql := l_sql_base || add_sql_conditions(l_rules(rulelist));
      
         l_handle := DBMS_SQL.OPEN_CURSOR;
         dbms_sql.parse(l_handle, l_sql, DBMS_SQL.NATIVE);
      
         EXECUTE IMMEDIATE l_sql BULK COLLECT
            INTO l_tmp_resultset;
      
         l_cnt := l_tmp_resultset.COUNT;
      
         l_result_set := l_result_set MULTISET UNION l_tmp_resultset;
         l_tmp_resultset.DELETE;
      
      END LOOP;
   
      o_result_set := l_result_set;
   
      l_result_set.DELETE;
   
   END apply_rules;

   PROCEDURE apply_exlcusions(io_resultset IN OUT NOCOPY t_scope_result_rows) IS
      l_ignorelist t_scope_result_rows := plsqlscope_metadata.upload_ignore_list;
      l_updateset  t_scope_result_rows := t_scope_result_rows();
   BEGIN
      dbms_application_info.set_action(action_name => 'Apply Checkstyle Exclusions');
   
      SELECT t_scope_result_row(object_owner, object_name, object_type, rule_name,
                                identifier, rule_desc, rule_category, line, SOURCE) BULK COLLECT
      INTO   l_updateset
      FROM   TABLE(io_resultset) src
      WHERE  NOT EXISTS (SELECT 1
              FROM   TABLE(l_ignorelist) ign
              WHERE  src.object_owner = NVL(ign.object_owner, src.object_owner)
              AND    src.object_name = NVL(ign.object_name, src.object_name)
              AND    src.object_type = NVL(ign.object_type, src.object_type)
              AND    src.rule_name = NVL(ign.rule_name, src.rule_name)
              AND    src.identifier = NVL(ign.identifier, src.identifier)
              AND    src.line = NVL(ign.line, src.line));
   
      io_resultset := l_updateset;
   END apply_exlcusions;

   PROCEDURE run_scope_objects(i_objects IN t_objects
                              ,o_results OUT NOCOPY t_scope_result_rows) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      l_path t_objects := i_objects;
   BEGIN
      dbms_application_info.set_action(action_name => 'Recompile Scope for Objects');
   
      plsqlscope_helper.recompile_with_scope_objects(i_run_paths => l_path);
   
      gather_identifiers(i_path => l_path);
      l_path.DELETE;
   
      apply_rules(o_result_set => o_results);
      apply_exlcusions(io_resultset => o_results);
   
      COMMIT;
   END run_scope_objects;

   PROCEDURE run_scope(i_schemas IN varchar2_tab
                      ,i_objects IN varchar2_tab
                      ,o_results OUT NOCOPY t_scope_result_rows) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   
      l_path        t_objects := get_object_list(i_schemas => i_schemas,
                                                 i_objects => i_objects);
      l_schema_path t_objects := t_objects();
   BEGIN
      dbms_application_info.set_action(action_name => 'Recompile Scope');
   
      IF i_objects.COUNT = 0 THEN
         --Workaround issue when schema compiled is schema where package is being executed
         --that creates a lock
         FOR listofschemas IN 1 .. i_schemas.COUNT
         LOOP
            IF i_schemas(listofschemas) = g_current_schema THEN
               l_schema_path := get_object_list(i_schemas => varchar2_tab(g_current_schema),
                                                i_objects => i_objects);
               plsqlscope_helper.recompile_with_scope_objects(i_run_paths => l_schema_path);
            ELSE
               plsqlscope_helper.recompile_with_scope_schema(i_schema => i_schemas(listofschemas));
            END IF;
         END LOOP;
      ELSE
         plsqlscope_helper.recompile_with_scope_objects(i_run_paths => l_path);
      END IF;
   
      gather_identifiers(i_path => l_path);
      l_path.DELETE;
   
      apply_rules(o_result_set => o_results);
      apply_exlcusions(io_resultset => o_results);
   
      COMMIT;
   
   END run_scope;

   PROCEDURE report_to_console(i_source_data IN t_scope_result_rows
                              ,o_data        OUT NOCOPY CLOB) IS
   
   BEGIN
      dbms_application_info.set_action(action_name => 'Get Console Report Clob');
      o_data := plsqlscope_helper.get_console_report(i_sourcedata => i_source_data);
   END report_to_console;

   PROCEDURE report_to_html(i_source_data  IN t_scope_result_rows
                           ,i_reporter_det IN t_reporter_rec
                           ,o_data         OUT NOCOPY CLOB) IS
   BEGIN
      dbms_application_info.set_action(action_name => 'Get HTML Report Clob');
      o_data := plsqlscope_helper.get_html_report(i_sourcedata => i_source_data,
                                                  i_root_path => i_reporter_det.rootpath);
   END report_to_html;

   PROCEDURE report_to_pmd(i_source_data  IN t_scope_result_rows
                          ,i_reporter_det IN t_reporter_rec
                          ,o_data         OUT NOCOPY CLOB) IS
   
   BEGIN
      dbms_application_info.set_action(action_name => 'Get PMD Report Clob');
      o_data := plsqlscope_helper.get_pmd_report(i_sourcedata => i_source_data,
                                                 i_root_path => i_reporter_det.rootpath,
                                                 i_object_path => i_reporter_det.objecttopath);
   END report_to_pmd;

   PROCEDURE report_to_checkstyle(i_source_data IN t_scope_result_rows
                                 ,o_data        OUT NOCOPY CLOB) IS
   
   BEGIN
      dbms_application_info.set_action(action_name => 'Get Checkstyle Report Clob');
      o_data := plsqlscope_helper.get_checkstyle_report(i_sourcedata => i_source_data,
                                                        i_root_path => 'test');
   END report_to_checkstyle;

   PROCEDURE report_to_csvexclusions(i_source_data IN t_scope_result_rows
                                    ,o_data        OUT NOCOPY CLOB) IS
   
   BEGIN
      dbms_application_info.set_action(action_name => 'Get CSV Exclusions Report Clob');
      o_data := plsqlscope_helper.get_exclusions_csv_report(i_sourcedata => i_source_data);
      
   END report_to_csvexclusions;

   PROCEDURE get_report_data(i_reporter    IN t_reporter_rec
                            ,i_source_data IN t_scope_result_rows
                            ,o_report      OUT NOCOPY CLOB) IS
   
      l_reporter t_reporter_rec;
   
   BEGIN
      dbms_application_info.set_action(action_name => 'Get Report Data');
   
      IF i_reporter.reporter_name IS NULL THEN
         l_reporter.reporter_name := 'CONSOLE';
      ELSE
         l_reporter := i_reporter;
      END IF;
   
      IF l_reporter.reporter_name = 'HTML' THEN
         report_to_html(i_source_data => i_source_data, i_reporter_det => l_reporter,
                        o_data => o_report);
      ELSIF l_reporter.reporter_name = 'PMD' THEN
         report_to_pmd(i_source_data => i_source_data, i_reporter_det => l_reporter,
                       o_data => o_report);
      ELSIF l_reporter.reporter_name = 'CHECKSTYLE' THEN
         report_to_checkstyle(i_source_data => i_source_data, o_data => o_report);
      ELSIF l_reporter.reporter_name = 'CSVEXCL' THEN
         report_to_csvexclusions(i_source_data => i_source_data, o_data => o_report);
      ELSE
         report_to_console(i_source_data => i_source_data, o_data => o_report);
      END IF;
   END get_report_data;

   PROCEDURE insert_into_buffer(i_line        VARCHAR2
                               ,i_line_id     NUMBER
                               ,i_reporter_id VARCHAR2) AS
   
   BEGIN
      INSERT INTO gtt_validation_results
         (reporter_id, text_id, text)
      VALUES
         (i_reporter_id, i_line_id, i_line);
   END insert_into_buffer;

   PROCEDURE collect_report_data_to_buffer(i_report_data IN CLOB
                                          ,i_report_id   IN VARCHAR2) AS
      l_length       NUMBER := dbms_lob.getlength(i_report_data);
      l_report_line  VARCHAR2(4000);
      l_offset       NUMBER := 1;
      l_line         NUMBER := 1;
      l_chunk_length NUMBER := 4000;
      l_tagendpos    NUMBER;
   BEGIN
      dbms_application_info.set_action(action_name => 'Collect report data to buffer');
   
      DELETE FROM gtt_validation_results
      WHERE  reporter_id = i_report_id;
   
      WHILE l_offset < l_length
      LOOP
         l_report_line := dbms_lob.substr(i_report_data, l_chunk_length, l_offset);
         l_tagendpos   := INSTR(l_report_line, chr(10), -1);
      
         IF l_length > l_chunk_length THEN
            IF l_tagendpos = 0 THEN
               l_report_line := dbms_lob.substr(i_report_data, l_length - l_offset,
                                                l_offset);
               l_offset      := l_offset + l_chunk_length;
            ELSE
               l_report_line := dbms_lob.substr(i_report_data, l_tagendpos, l_offset);
               l_offset      := l_offset + l_tagendpos;
            END IF;
         ELSE
            l_report_line := dbms_lob.substr(i_report_data, l_length - l_offset, l_offset);
            l_offset      := l_offset + l_chunk_length;
         END IF;
      
         insert_into_buffer(i_line => l_report_line, i_line_id => l_line,
                            i_reporter_id => i_report_id);
         l_line := l_line + 1;
      END LOOP;
   END collect_report_data_to_buffer;

   FUNCTION get_table_text(i_report_id IN VARCHAR2) RETURN varchar2_tab AS
      l_results varchar2_tab;
   BEGIN
      SELECT text BULK COLLECT
      INTO   l_results
      FROM   gtt_validation_results
      WHERE  reporter_id = i_report_id
      ORDER  BY text_id ASC;
   
      RETURN l_results;
   END;

   FUNCTION get_data_clob(i_report_id IN VARCHAR2) RETURN CLOB AS
      l_results varchar2_tab := get_table_text(i_report_id => i_report_id);
      l_clob    CLOB;
   BEGIN
      l_clob := plsqlscope_helper.table_to_clob(i_text_table => l_results);
      RETURN l_clob;
   END;

   PROCEDURE print_report(i_report_data IN CLOB) AS
   
   BEGIN
      plsqlscope_helper.print_clob_by_line(i_data => i_report_data);
   END print_report;

   PROCEDURE print_report(i_report_id IN VARCHAR2) AS
   
   BEGIN
      plsqlscope_helper.print_clob_by_line(i_data => get_data_clob(i_report_id => i_report_id));
   END print_report;

   FUNCTION output_buffer(i_report_id IN VARCHAR2) RETURN varchar2_tab
      PIPELINED AS
      l_text_tab varchar2_tab := get_table_text(i_report_id);
   BEGIN
      FOR textlines IN 1 .. l_text_tab.COUNT
      LOOP
         PIPE ROW(l_text_tab(textlines));
      END LOOP;
   END output_buffer;

   PROCEDURE run_and_print_reporter(i_reporter    IN t_reporter_rec
                                   ,i_source_data IN t_scope_result_rows) AS
      l_data CLOB;
   BEGIN
      get_report_data(i_reporter => i_reporter, i_source_data => i_source_data,
                      o_report => l_data);
   
      collect_report_data_to_buffer(i_report_data => l_data,
                                    i_report_id => i_reporter.reporter_name);
   
      --print_report(i_report_data => l_data);
      print_report(i_report_id => i_reporter.reporter_name);
   END run_and_print_reporter;

   PROCEDURE run_and_collect_report(i_reporter    IN t_reporter_rec
                                   ,i_source_data IN t_scope_result_rows) AS
      l_data CLOB;
   BEGIN
      get_report_data(i_reporter => i_reporter, i_source_data => i_source_data,
                      o_report => l_data);
      collect_report_data_to_buffer(i_report_data => l_data,
                                    i_report_id => i_reporter.reporter_name);
   END run_and_collect_report;

   PROCEDURE run_scope_with_print(i_schemas  IN varchar2_tab
                                 ,i_objects  IN varchar2_tab
                                 ,i_reporter IN t_reporter_rec) IS
      l_result_set t_scope_result_rows := t_scope_result_rows();
   
   BEGIN
      run_scope(i_schemas => i_schemas, i_objects => i_objects, o_results => l_result_set);
      run_and_print_reporter(i_reporter => i_reporter, i_source_data => l_result_set);
   END run_scope_with_print;

   PROCEDURE runner(i_schemas  IN varchar2_tab
                   ,i_objects  IN varchar2_tab
                   ,i_reporter IN t_reporter_tab) AS
      l_result_set t_scope_result_rows;
   BEGIN
      run_scope(i_schemas => i_schemas, i_objects => i_objects, o_results => l_result_set);
   
      FOR reporters IN i_reporter.FIRST .. i_reporter.LAST
      LOOP
         run_and_collect_report(i_reporter => i_reporter(reporters),
                                i_source_data => l_result_set);
      END LOOP;
   END runner;

   FUNCTION run(i_schema IN VARCHAR2 DEFAULT NULL) RETURN t_scope_result_rows
      PIPELINED IS
      l_schema varchar2_tab := varchar2_tab(coalesce(i_schema, g_current_schema));
   
      l_objects    varchar2_tab := varchar2_tab();
      l_result_set t_scope_result_rows := t_scope_result_rows();
   BEGIN
      set_module;
      run_scope(i_schemas => l_schema, i_objects => l_objects, o_results => l_result_set);
   
      FOR resultset IN 1 .. l_result_set.COUNT
      LOOP
         PIPE ROW(l_result_set(resultset));
      END LOOP;
   END run;

   PROCEDURE run(i_schema   IN VARCHAR2 DEFAULT NULL
                ,i_reporter IN t_reporter_rec DEFAULT NULL) IS
      l_schema varchar2_tab := varchar2_tab(coalesce(i_schema, g_current_schema));
   
      l_objects varchar2_tab := varchar2_tab();
   
   BEGIN
      set_module;
      run_scope_with_print(i_schemas => l_schema, i_objects => l_objects,
                           i_reporter => i_reporter);
   END run;

   FUNCTION run(i_schema IN VARCHAR2 DEFAULT NULL
               ,i_object IN VARCHAR2) RETURN t_scope_result_rows
      PIPELINED IS
      l_schema varchar2_tab := varchar2_tab(coalesce(i_schema, g_current_schema));
   
      l_objects    varchar2_tab := varchar2_tab(i_object);
      l_result_set t_scope_result_rows := t_scope_result_rows();
   BEGIN
      set_module;
      run_scope(i_schemas => l_schema, i_objects => l_objects, o_results => l_result_set);
   
      FOR resultset IN 1 .. l_result_set.COUNT
      LOOP
         PIPE ROW(l_result_set(resultset));
      END LOOP;
   END run;

   PROCEDURE run(i_schema   IN VARCHAR2 DEFAULT NULL
                ,i_object   IN VARCHAR2
                ,i_reporter IN t_reporter_rec DEFAULT NULL) IS
   
      l_schema varchar2_tab := varchar2_tab(coalesce(i_schema, g_current_schema));
   
      l_objects varchar2_tab := varchar2_tab(i_object);
   BEGIN
      set_module;
      run_scope_with_print(i_schemas => l_schema, i_objects => l_objects,
                           i_reporter => i_reporter);
   END run;

   PROCEDURE run(i_schemas  IN varchar2_tab
                ,i_reporter IN t_reporter_rec DEFAULT NULL) IS
      l_schema varchar2_tab := coalesce(i_schemas, varchar2_tab(g_current_schema));
   
      l_objects varchar2_tab := varchar2_tab();
   BEGIN
      set_module;
      run_scope_with_print(i_schemas => l_schema, i_objects => l_objects,
                           i_reporter => i_reporter);
   END run;

   PROCEDURE run(i_objects  IN varchar2_tab
                ,i_reporter IN t_reporter_rec DEFAULT NULL) IS
      l_schema varchar2_tab := varchar2_tab(g_current_schema);
   
      l_objects varchar2_tab := i_objects;
   BEGIN
      set_module;
      run_scope_with_print(i_schemas => l_schema, i_objects => l_objects,
                           i_reporter => i_reporter);
   END run;

   PROCEDURE run(i_schema   IN VARCHAR2
                ,i_objects  IN varchar2_tab
                ,i_reporter IN t_reporter_rec DEFAULT NULL) IS
      l_schema varchar2_tab := varchar2_tab(coalesce(i_schema,
                                                     sys_context('userenv',
                                                                  'current_schema')));
   
      l_objects varchar2_tab := i_objects;
   BEGIN
      set_module;
      run_scope_with_print(i_schemas => l_schema, i_objects => l_objects,
                           i_reporter => i_reporter);
   END run;

   PROCEDURE run(i_object_list IN t_objects
                ,i_reporter    IN t_reporter_rec DEFAULT NULL) IS
      l_result_set t_scope_result_rows := t_scope_result_rows();
   BEGIN
      set_module;
      run_scope_objects(i_objects => i_object_list, o_results => l_result_set);
      run_and_print_reporter(i_reporter => i_reporter, i_source_data => l_result_set);
   END run;

END PLSSQLSCOPE_API;
/
