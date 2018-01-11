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

CREATE OR REPLACE PACKAGE BODY PLSQLSCOPE_METADATA IS

   g_rules_list  t_scope_rules := t_scope_rules();
   g_ignore_list t_scope_result_rows := t_scope_result_rows();

   FUNCTION init_self RETURN t_object IS
      l_schema   VARCHAR2(30) := sys_context('userenv', 'current_schema');
      l_object   VARCHAR2(30) := $$PLSQL_UNIT;
      l_fullname t_object;
   BEGIN
      l_fullname := t_object(l_object, l_schema, NULL);
      RETURN l_fullname;
   END init_self;

   PROCEDURE add_rule(i_rule IN t_scope_rule) IS
   
   BEGIN
      g_rules_list.extend;
      g_rules_list(g_rules_list.LAST) := i_rule;
   END;

   PROCEDURE add_exclusion(i_rule IN t_scope_result_row) IS
      l_subscript_cnt NUMBER := g_ignore_list.COUNT + 1;
   BEGIN
      g_ignore_list.extend;
      g_ignore_list(l_subscript_cnt) := i_rule;
   END add_exclusion;

   PROCEDURE load_rules_from_table(o_rules_list OUT NOCOPY t_scope_rules) IS
      CURSOR c_get_rules IS
         SELECT rulename
               ,ruledescription
               ,identifierusage
               ,identifiertype
               ,identifierplacement
               ,ruleregex
               ,rule_category
         FROM   checkstyle_rules
         ORDER  BY rule_category
                  ,rulename
                  ,identifiertype
                  ,identifierusage;
   
      TYPE t_rules_tab IS TABLE OF c_get_rules%ROWTYPE;
      l_rules_tab t_rules_tab;
   BEGIN
      OPEN c_get_rules;
      LOOP
         FETCH c_get_rules BULK COLLECT
            INTO l_rules_tab;
         EXIT WHEN l_rules_tab.COUNT = 0;
         FOR rules IN 1 .. l_rules_tab.COUNT
         LOOP
            add_rule(t_scope_rule(rulename => l_rules_tab(rules).rulename,
                                  ruledescription => l_rules_tab(rules).ruledescription,
                                  identifierusage => l_rules_tab(rules).identifierusage,
                                  identifiertype => l_rules_tab(rules).identifiertype,
                                  identifierplacement => l_rules_tab(rules)
                                                          .identifierplacement,
                                  ruleregex => l_rules_tab(rules).ruleregex,
                                  category => l_rules_tab(rules).rule_category));
         END LOOP;
      END LOOP;
      CLOSE c_get_rules;
      o_rules_list := g_rules_list;
      g_rules_list.DELETE;
   END load_rules_from_table;

   PROCEDURE load_ignorelist_from_table(o_ignore_list OUT NOCOPY t_scope_result_rows) IS
      CURSOR c_get_exceptions IS
         SELECT ex.object_owner
               ,ex.object_name
               ,ex.object_type
               ,ex.rule_name
               ,ex.rule_category
               ,ex.rule_identifier
               ,ex.line
         FROM   checkstyle_exclusions ex
         ORDER  BY object_owner
                  ,object_name
                  ,object_type
                  ,rule_category
                  ,rule_name
                  ,rule_identifier
                  ,line;
   
      TYPE t_exceptions_tab IS TABLE OF c_get_exceptions%ROWTYPE;
      l_exceptions_tab t_exceptions_tab;
   BEGIN
      OPEN c_get_exceptions;
      LOOP
         FETCH c_get_exceptions BULK COLLECT
            INTO l_exceptions_tab;
         EXIT WHEN l_exceptions_tab.COUNT = 0;
         FOR exceptionsrow IN 1 .. l_exceptions_tab.COUNT
         LOOP
            add_exclusion(t_scope_result_row(object_owner => l_exceptions_tab(exceptionsrow)
                                                             .object_owner,
                                             object_name => l_exceptions_tab(exceptionsrow)
                                                             .object_name,
                                             object_type => l_exceptions_tab(exceptionsrow)
                                                             .object_type,
                                             rule_name => l_exceptions_tab(exceptionsrow)
                                                           .rule_name, rule_desc => NULL,
                                             rule_category => l_exceptions_tab(exceptionsrow)
                                                               .rule_category,
                                             SOURCE => NULL,
                                             identifier => l_exceptions_tab(exceptionsrow)
                                                            .rule_identifier,
                                             line => l_exceptions_tab(exceptionsrow).line));
         END LOOP;
      END LOOP;
      CLOSE c_get_exceptions;
      o_ignore_list := g_ignore_list;
      g_ignore_list.DELETE;
   END load_ignorelist_from_table;

   /*Depracated due to moving config into tables */
   PROCEDURE define_rules(o_rules_list OUT NOCOPY t_scope_rules) IS
   BEGIN
      add_rule(t_scope_rule('ConstantDeclaration',
                            'Violated convention that constants names should spelled in uppercase only',
                            'DECLARATION', 'CONSTANT', '',
                            'NOT REGEXP_LIKE(SOURCE,UPPER(NAME))', 'CASING CONVENTION'));
   
      add_rule(t_scope_rule('FormalIn',
                            'Violated convention that input parameters be prefixed with i_',
                            'DECLARATION', 'FORMAL IN', '',
                            'NOT REGEXP_LIKE(NAME, ''^(i_)'',''i'') AND CONTEXT_TYPE != ''RECORD''',
                            'NAMING CONVENTION'));
   
      add_rule(t_scope_rule('FormalInOut',
                            'Violated convention that (input and output) parameters be prefixed with io_',
                            'DECLARATION', 'FORMAL IN OUT', '',
                            'NOT REGEXP_LIKE(NAME, ''^(io_)'',''i'') AND CONTEXT_TYPE != ''RECORD''',
                            'NAMING CONVENTION'));
   
      add_rule(t_scope_rule('FormalOut',
                            'Violated convention that output parameters be prefixed with o_',
                            'DECLARATION', 'FORMAL OUT', '',
                            'NOT REGEXP_LIKE(NAME, ''^(o_)'',''i'') AND CONTEXT_TYPE != ''RECORD''',
                            'NAMING CONVENTION'));
   
      add_rule(t_scope_rule('GlobalVariable',
                            'Violated convention that global variables should be prefixed with g_',
                            'DECLARATION', 'VARIABLE', 'GLOBAL',
                            'NOT REGEXP_LIKE(NAME, ''^(g_)'',''i'') AND CONTEXT_TYPE != ''RECORD''',
                            'NAMING CONVENTION'));
   
      add_rule(t_scope_rule('LocalVariable',
                            'Violated convention that local variables should be prefixed with l_',
                            'DECLARATION', 'VARIABLE', 'LOCAL',
                            'NOT REGEXP_LIKE(NAME, ''^(l_)'',''i'') AND CONTEXT_TYPE != ''RECORD''',
                            'NAMING CONVENTION'));
   
      add_rule(t_scope_rule('PLSQLWarningsInfo', 'Info Warning Detected', 'WARNING',
                            'PLWARNINGS_INFO', '', '', 'PLSQLWARNINGS INFO'));
   
      add_rule(t_scope_rule('PLSQLWarningsSevere', 'Severe Warning Detected', 'WARNING',
                            'PLWARNINGS_SEVERE', '', '', 'PLSQLWARNINGS SEVERE'));
   
      add_rule(t_scope_rule('TypesNamingConvention',
                            'Violated convention that type definitions should be prefixed with t_',
                            'DECLARATION', 'RECORD', '',
                            'NOT REGEXP_LIKE(NAME, ''^(t_)'',''i'') AND CONTEXT_TYPE != ''RECORD''',
                            'NAMING CONVENTION'));
   
      add_rule(t_scope_rule('VariableDeclaration',
                            'Violated convention that variable names should spelled in lowercase only',
                            'DECLARATION', 'VARIABLE', '',
                            'NOT REGEXP_LIKE(SOURCE,LOWER(NAME))', 'CASING CONVENTION'));
   
      o_rules_list := g_rules_list;
      g_rules_list.DELETE;
   END define_rules;

   PROCEDURE define_exclusions(o_ignore_list OUT NOCOPY t_scope_result_rows) IS
   BEGIN
   
      add_exclusion(t_scope_result_row(object_owner => NULL, object_name => NULL,
                                       object_type => NULL,
                                       rule_name => 'PLSQLWarningsSevere',
                                       rule_desc => NULL, rule_category => NULL,
                                       SOURCE => NULL, identifier => '5018', line => NULL));
   
      add_exclusion(t_scope_result_row(object_owner => NULL, object_name => NULL,
                                       object_type => NULL,
                                       rule_name => 'PLSQLWarningsSevere',
                                       rule_desc => NULL, rule_category => NULL,
                                       SOURCE => NULL, identifier => '5005', line => NULL));
   
      add_exclusion(t_scope_result_row(object_owner => NULL, object_name => NULL,
                                       object_type => NULL,
                                       rule_name => 'PLSQLWarningsInfo', rule_desc => NULL,
                                       rule_category => NULL, SOURCE => NULL,
                                       identifier => '6009', line => NULL));
   
      o_ignore_list := g_ignore_list;
      g_ignore_list.DELETE;
   END define_exclusions;

   FUNCTION upload_ignore_list RETURN t_scope_result_rows IS
      l_ignorelist t_scope_result_rows;
   BEGIN
      load_ignorelist_from_table(o_ignore_list => l_ignorelist);
   
      /* Depracated due to moving rules into table */
      --define_exclusions(o_ignore_list => l_ignorelist);
      RETURN l_ignorelist;
   END;

   FUNCTION upload_rules RETURN t_scope_rules IS
      l_scope_rules t_scope_rules;
   BEGIN
      load_rules_from_table(o_rules_list => l_scope_rules);
   
      /* Depracated due to moving rules into table */
      --define_rules(o_rules_list => l_scope_rules);
   
      RETURN l_scope_rules;
   END upload_rules;

   FUNCTION get_exclusions_csv_format RETURN t_csv_row
      PIPELINED IS
      l_result t_scope_result_rows := plscope.t_scope_result_rows();
      l_csvrow VARCHAR2(32000);
   BEGIN
      -- Call the function
      l_result := plscope.plsqlscope_metadata.upload_ignore_list;
      FOR i IN 1 .. l_result.count
      LOOP
         l_csvrow := '"' || l_result(i).rule_name || '","' || l_result(i).rule_category ||
                     '","' || l_result(i).identifier || '","' || l_result(i).line ||
                     '","' || l_result(i).object_type || '","' || l_result(i).object_name ||
                     '","' || l_result(i).object_owner || '"';
         PIPE ROW(l_csvrow);
      END LOOP;
   
      RETURN;
   EXCEPTION
      WHEN NO_DATA_NEEDED THEN
         RETURN;
   END get_exclusions_csv_format;

   FUNCTION get_rules_csv_format RETURN t_csv_row
      PIPELINED IS
      l_result t_scope_rules := plscope.t_scope_rules();
      l_csvrow VARCHAR2(32000);
   BEGIN
      -- Call the function
      l_result := plscope.plsqlscope_metadata.upload_rules;
      FOR i IN 1 .. l_result.count
      LOOP
         l_csvrow := '"' || l_result(i).rulename || '","' || l_result(i).ruledescription ||
                     '","' || l_result(i).identifierusage || '","' || l_result(i)
                    .identifiertype || '","' || l_result(i).identifierplacement || '","' || l_result(i)
                    .ruleregex || '","' || l_result(i).category || '"';
         PIPE ROW(l_csvrow);
      END LOOP;
   
      RETURN;
   EXCEPTION
      WHEN NO_DATA_NEEDED THEN
         RETURN;
   END get_rules_csv_format;

END PLSQLSCOPE_METADATA;
/
