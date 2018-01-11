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

-- Create table
create global temporary table GTT_SCOPE_ROWS
(
  name         VARCHAR2(50),
  type         VARCHAR2(50),
  usage        VARCHAR2(50),
  line         NUMBER,
  object_type  VARCHAR2(50),
  object_name  VARCHAR2(50),
  source       VARCHAR2(4000),
  owner        VARCHAR2(50),
  tobeignored  CHAR(1),
  context_type VARCHAR2(50),
  end_line     NUMBER,
  placement    VARCHAR2(50)
)
on commit delete rows;
