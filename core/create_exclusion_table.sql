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
 
CREATE TABLE checkstyle_exclusions
(
  rule_name         VARCHAR2(50),
  rule_category     VARCHAR2(50),
  rule_identifier   VARCHAR2(50),
  line              NUMBER,
  object_type       VARCHAR2(50),
  object_name       VARCHAR2(30),
  object_owner      VARCHAR2(30)
);
