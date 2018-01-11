#!/bin/bash

plscope_user=$1
plscope_user_password=$2
testdb=$3
deploy_password=$4
tablespace=$5
component_rules_folder=$6
component_excl_folder=$7

function printUsage
(
echo "Usage:"
echo "jenkins_install.sh plscope_user (req*) - plscope username\\"
echo "                   plscope_user_password (req*) - pslcope password\\"
echo "                   testdb (req*) - Database SID\\"
echo "                   deploy_password (req*) - Deploy Password  \\"
echo "                   tablespace - Optional Tablespce for install (eg. USERS_AUTO_01) if empty default to USERS \\"
echo "                   component_rules_folder - Optional Path to .dat file to overide, relative to execution folder(if empty takes a one from git)\\"
echo "                   component_excl_folder - Optional path to .dat file to overide relative to execution folder (if empty use a git one)\\"
)

if [ "X${plscope_user}" = "X" ] ; then
   echo "ERROR: Missing PLSCOPE user"
   printUsage
   exit 1
fi

if [ "X${plscope_user_password}" = "X" ] ; then
   echo "ERROR: Missing PLSCOPE Password"
   printUsage
   exit 1
fi

if [ "X${testdb}" = "X" ] ; then
   echo "ERROR: Missing Database SID"
   printUsage
   exit 1
fi

if [ "X${deploy_password}" = "X" ] ; then
   echo "ERROR: Missing Deploy Password"
fi

if [ "X${tablespace}" = "X" ] ; then
   echo "INFO: Using Default DB tablespace"
fi

if [ "X${component_rules_folder}" = "X" ] ; then
   RULE_DIR='data/rules.dat'
   echo "INFO: DEFAULT RULE: $RULE_DIR"
else
   RULE_DIR=$component_rules_folder
   echo "INFO: USING RULE: $RULE_DIR" 
fi

if [ "X${component_excl_folder}" = "X" ] ; then
   EXCL_DIR='data/exceptionlist.dat'
   echo "INFO: DEFAULT EXCLUSIONS: $EXCL_DIR"
else
   EXCL_DIR=$component_excl_folder
   echo "INFO: USING EXCLUSIONS: $EXCL_DIR" 
fi



deploy_user=sys


start=`date +%s`

 
logfile="install_tests.log"
rm -rf ${logfile}

###Drop user
echo "Drop User"
sqlplus "${deploy_user}"/"${deploy_password}"@"${testdb}" as sysdba @drop_plscope_user.sql "${plscope_user}" >> ${logfile}

###Install PLSCOPE
echo "Install Framework"
sqlplus "${deploy_user}"/"${deploy_password}"@"${testdb}" as sysdba @install.sql "${plscope_user}" "${plscope_user_password}" "${tablespace}" >> ${logfile}

###Load Rules Data
echo "Load Checsktyle Rules"
sqlldr "${plscope_user}"/"${plscope_user_password}"@"${testdb}"  data=$RULE_DIR control=data/rules.ctl bad=load_rules.bad  log=load_rules.log

###Load Ignore List Data
echo "Load Exceptions"
sqlldr "${plscope_user}"/"${plscope_user_password}"@"${testdb}"  data=$EXCL_DIR control=data/exceptionlist.ctl bad=load_exceptions.bad  log=load_exceptions.log

end=`date +%s`
runtime=$((end-start))
echo "Setup of PLSCOPE run took: ${runtime} seconds"
echo "Please check csv_exclusions_candidate.dat file if you want to add some exclusions to code"