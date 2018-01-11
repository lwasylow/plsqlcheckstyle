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

CREATE TABLE checkstyle_rules 
(
   rulename            VARCHAR2(255),
   ruledescription     VARCHAR2(4000),
   identifierusage     VARCHAR2(255),
   identifiertype      VARCHAR2(255),
   identifierplacement VARCHAR2(255),
   ruleregex           VARCHAR2(2000),
   rule_category            VARCHAR2(255)
);
