
-- UTLY_VW_FK.View.sql
-- MySQL
drop view if exists UTLY_VW_FK;

create view UTLY_VW_FK
as
SELECT 
    `information_schema`.`KEY_COLUMN_USAGE`.`TABLE_NAME` AS `TABLE_NAME`,
    `information_schema`.`KEY_COLUMN_USAGE`.`COLUMN_NAME` AS `COLUMN_NAME`,
    `information_schema`.`KEY_COLUMN_USAGE`.`CONSTRAINT_NAME` AS `FK_NAME`,
    `information_schema`.`KEY_COLUMN_USAGE`.`REFERENCED_TABLE_NAME` AS `FK_TABLE_NAME`,
    `information_schema`.`KEY_COLUMN_USAGE`.`REFERENCED_COLUMN_NAME` AS `FK_COLUMN_NAME`
FROM
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
WHERE
    ((1 = 1)
        AND (`information_schema`.`KEY_COLUMN_USAGE`.`REFERENCED_TABLE_NAME` IS NOT NULL)
        AND (`information_schema`.`KEY_COLUMN_USAGE`.`TABLE_SCHEMA` = DATABASE()))
        ;
        
