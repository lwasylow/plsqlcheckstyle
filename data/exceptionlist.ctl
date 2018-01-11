LOAD DATA
REPLACE
INTO TABLE checkstyle_exclusions
fields terminated by ',' 
optionally enclosed by '"'
trailing nullcols
(
  rule_name         CHAR(50),
  rule_category     CHAR(50),
  rule_identifier   CHAR(50),
  line              CHAR "TO_NUMBER(:line)",
  object_type       CHAR(50),
  object_name       CHAR(30),
  object_owner      CHAR(30)
)
