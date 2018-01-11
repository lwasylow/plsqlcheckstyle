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

CREATE OR REPLACE TYPE T_SCOPE_RESULT_ROW AS OBJECT
(
  object_owner VARCHAR2(30),
  object_name  VARCHAR2(30),
  object_type  VARCHAR2(13),
  rule_name	   VARCHAR2(255),
  identifier   VARCHAR2(55),
  rule_desc	   VARCHAR2(4000),
  rule_category VARCHAR2(255),
  line         NUMBER,
  source       VARCHAR2(4000)
)
/
