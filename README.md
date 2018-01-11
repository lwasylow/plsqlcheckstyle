- [Overview](#overview)
- [Usage](#usage)
- [Sample Output and reading a rules.](#sample-output-and-reading-a-rules)
- [Existing rules and adding new ones](#existing-rules-and-adding-new-ones)
- [Exclusions or so called ignore list.](#exclusions-or-so-called-ignore-list)

# Overview

The purpose of this package is to run series of regexp expression that will do basic checkstyles on the code.
Using a plscope =all and dba_identifiers plus a dba_source we are able to parse the metadata and find the lines of code that breaking the basic rules. This rules that can be reported back to user in form of HTML, PMD or simple as sql query results.

# Usage
The code can be called from the sql env as well as run via jenkins job or shell scripts.

NOTE: Please be aware that user name where to package is installed depends on the installation in env (here it is plsqlscope, in CCS docker is plscope etc.)

There are two reporters created HTML and PMD. We can call them as follow which results in data being printed to console.

```sql

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

```

Above can be spooled to file using:

```sql

    SELECT * FROM TABLE( plssqlscope_api.output_buffer(i_report_id => 'HTML'));
    SELECT * FROM TABLE( plssqlscope_api.output_buffer(i_report_id => 'PMD'));

```

We can also get results in form of the sql data:

```sql
    select * from table(plsqlscope.plssqlscope_api.run(i_schema => schemaname ))
```
or overloaded
```sql
    select * from table(plsqlscope.plssqlscope_api.run(i_schema => schemaname , i_object => object_name))
```
    
More will be written if necessary. Please see code specs for more access paths.
    
# Sample Output and reading a rules.
Sample output from SQL :
```sql   
    select * from table(plsqlscope.plssqlscope_api.run(i_schema => 'OPR' , i_object => 'CHECK_STB'))
```

|OWNER|OBJECT NAME|OBJECT TYPE|RULE NAME|IDENTIFER|RULE DSC|RULE CAT|LINE|SOURCE|  
|-----|-----------|-----------|---------|-------- |--------|--------|----|------|   
| OPR | CHECK_STB | PACKAGE BODY | LocalVariable | V_INVALID |Violated convention that local variables should be prefixed with l_ | NAMING CONVENTION | 51 | v_invalid  NUMBER := 0; |
| OPR |	CHECK_STB | PACKAGE BODY | LocalVariable | V_FEEDBACK | Violated convention that local variables should be prefixed with l_ | NAMING CONVENTION | 52 |      v_feedback      opr.orfilefeedback.feedback%TYPE;|
|OPR | CHECK_STB | PACKAGE BODY | LocalVariable | V_FILESIZE | Violated convention that local variables should be prefixed with l_ | NAMING CONVENTION | 53 |	      v_filesize      NUMBER;|
|OPR|CHECK_STB|PACKAGE BODY|LocalVariable|V_DUPILATES|Violated convention that local variables should be prefixed with l_|	NAMING CONVENTION|54|	      v_dupilates     NUMBER;
|OPR|CHECK_STB|PACKAGE BODY|LocalVariable|V_FILESIZELIMIT|Violated convention that local variables should be prefixed with l_|	NAMING CONVENTION|55|	      v_filesizelimit NUMBER := opr.maintainconfig.getconfvalue(i_configgroup => 'FILESIZE',
|OPR|CHECK_STB|PACKAGE BODY|LocalVariable|V_RSLT|Violated convention that local variables should be prefixed with l_|	NAMING CONVENTION|8|	      v_rslt NUMBER;

# Existing rules and adding new ones    

The defining a new rule should be done carefully and with consideration, ideally also reviewed by other teammates.
This can be done by updating a rules.dat file which is in sqlldr format in folder /data in project code base.

Here is a list of current rules defined.
 1. Convention that constants names should spelled in uppercase only
 2. Convention that input parameters be prefixed with i_
 3. Convention that (input and output) parameters be prefixed with io_
 4. Convention that output parameters be prefixed with o_
 5. Convention that global variables should be prefixed with g_
 6. Convention that local variables should be prefixed with l_
 7. Info Warning Detected - PSQL WARNINGS
 8. Severe Warning Detected - PSQL WARNINGS
 9. Convention that variable names should spelled in lowercase only
 10. Convention that type definitions should be prefixed with t_

# Exclusions or so called ignore list.

From time to time there is a need for ignoring the rule in the code either for legacy or some other important reason.
This should be done with consideration and with review from your manager/coleague.

To add a new ignore list we have to supply a few values, we can exclude diffrent levels or combine them together.
 1. Schema level
 2. Object Level
 3. Variable level
 4. Line Level
 5. Rule name level
 6. Rule name category

e.g.

|RULE NAME|RULE CAT|RULE IDENTIFIER|LINE|OBJECT TYPE|OBJECT NAME|OBJECT OWNER|
|---------|--------|---------------|----|-----------|-----------|------------|
|PLSQLWarningsSevere||5018|||||

Rule above will exclude all results returned for rule name :PLSQLWarningsSevere and identifier 5018.

File to be modifed exists in /data folder with name exceptionlist.dat