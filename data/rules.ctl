LOAD DATA
REPLACE
INTO TABLE checkstyle_rules
fields terminated by ',' optionally enclosed by '"'
(
   rulename            CHAR(255),
   ruledescription     CHAR(4000),
   identifierusage     CHAR(255),
   identifiertype      CHAR(255),
   identifierplacement CHAR(255),
   ruleregex           CHAR(2000),
   rule_category       CHAR(255)
)
