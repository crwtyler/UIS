
-- UTLY_EXPORT_TO_TABLE.Procedure.sql
-- MySQL
DELIMITER $$

DROP PROCEDURE IF EXISTS `UTLY_EXPORT_DATA` $$
CREATE PROCEDURE `UTLY_EXPORT_DATA`(
    p_source_table VARCHAR(64), IN p_where TEXT, IN p_target_table VARCHAR(64), IN p_options VARCHAR(50))
BEGIN
/*

2013-11-07 CT: Created
2013-11-11 CT: Added more types (still more need to be added)
2025-09-30 CRT: changed name to UTLY_EXPORT_DATA and added seperate target table name, made outputtable a constant. fix
2025-10-22 CRT: Fixed order of instanciated columns in created select (group by ) and applied options filter


This will output select statements for any table with a filter (where statement)

call UTLC_EXPORT_TO_TABLE 'tablename', ' where thing = ''condition'' ', 'tablename_for_stmts';

Target table should be the table name necessary for the inserts.

Data will reside in the output table, which should be:

create table UTLY_SQL_STATEMENTS (
  STATEMENT_ORDER INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  STATEMENT_TEXT TEXT
);




*/




    DECLARE v_SQL LONGTEXT;
    DECLARE v_column_name varchar(64);
    DECLARE v_column_type varchar(64);
    DECLARE v_result LONGTEXT;
    DECLARE v_CL_SQL LONGTEXT;
	DECLARE v_output_table VARCHAR(64) DEFAULT 'UTLY_SQL_STATEMENTS';
	DECLARE v_old_maxlength INT;

    DECLARE no_more_rows BOOLEAN;

    DECLARE cur_Columns CURSOR FOR
    select
       COLUMN_NAME,
        COLUMN_TYPE
       from information_schema.columns
        where table_schema = DATABASE()
    --    and DATA_TYPE IN ('varchar','char','BLOB','TEXT','SET')
       -- and IS_NULLABLE = 'YES'
       AND NOT((EXTRA LIKE '%auto_increment%' AND p_options LIKE '%-no_identity%' ))
       AND (p_options NOT LIKE CONCAT('%','-exclude:',COLUMN_NAME,'%'))
        and TABLE_NAME = p_source_table
        ORDER BY ORDINAL_POSITION  
     ;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET no_more_rows = TRUE;


 SET SESSION group_concat_max_len = 100000;

-- Get the first part of the Insert statement - Columns list

select
   INSERTSQL into v_CL_SQL
FROM
(
 select
   CONCAT
    (
      'INSERT IGNORE INTO `',p_target_table,'` (',
      GROUP_CONCAT(
        '  ', CONCAT('`',COLUMN_NAME,'`') ORDER BY ORDINAL_POSITION SEPARATOR ','
      ),
    ')  '
    ) AS INSERTSQL
       from information_schema.columns
        where table_schema = DATABASE()
    --    and DATA_TYPE IN ('varchar','char','BLOB','TEXT','SET')
       -- and IS_NULLABLE = 'YES'
       AND NOT((EXTRA LIKE '%auto_increment%' AND p_options LIKE '%-no_identity%' ))
       AND (p_options NOT LIKE CONCAT('%','-exclude:',COLUMN_NAME,'%'))
        and TABLE_NAME = p_source_table
        ORDER BY ORDINAL_POSITION  
 ) THING;

    SET no_more_rows = FALSE; 
    
    OPEN cur_Columns;
    
    column_loop: LOOP
    
    FETCH cur_Columns INTO v_column_name,v_column_type;
    
    IF no_more_rows THEN
        CLOSE cur_Columns;
        LEAVE column_loop;
    END IF;
    
  --  SET @v_SQL = v_SQL;

  --  PREPARE STMT FROM @v_SQL;

  --  EXECUTE STMT;

    SET v_result = CONCAT(IFNULL(v_result,''),' ',IFNULL(v_column_name,''));


    END LOOP;

-- ------------
-- Create Dynamic SQL
-- Create a select statement with a column 'SQL_INSERT' which contains all values
-- in the form of an INSERT statement
-- ------------

/*

The procedure operated in three parts which are concatinated together
Part 1:  INSERT INT0 <tablename> (<values list>) was already created in v_CL_SQL

Part 2:  The Values list:  This concatinates every column in the table into a vlues list.
Null values are string-ified as 'Null'
Values are string-ified differently according to type, in the Case statement below
Everything is escaped as this is Dynamic SQL
commas and quotes (when applicable) that show in the final values statement are double-escaped

Part 3 - The fiter (contains a where statement) from the calling parameter is attached

*/

select
CONCAT(
	'SELECT CONCAT(',
  '\'',
  v_CL_SQL,' VALUES (\', ',
	'CONCAT_WS(\',\', ',
	GROUP_CONCAT(
  CASE
  WHEN DATA_TYPE IN ('varchar','char','text','tinytext','mediumtext','longtext') THEN
		CONCAT(
			'CASE WHEN `',
			COLUMN_NAME,
			'` IS NULL THEN \'NULL\' ELSE ',
			'CONCAT(\'\\\'\',REPLACE(`', COLUMN_NAME,  '`,\'\\\'\',\'\\\\\\\'\'),\'\\\'\')',
			' END '
			)
  WHEN DATA_TYPE IN ('tinyblob','blob','mediumblob','longblob') THEN
		CONCAT(
			'CASE WHEN `',
			COLUMN_NAME,
			'` IS NULL THEN \'NULL\' ELSE ',
			'CONCAT(\'0x\',HEX(`', COLUMN_NAME,  '`),\'\')',
			' END '
			)
  ELSE
		CONCAT(
			'CASE WHEN `',
			COLUMN_NAME,
			'` IS NULL THEN \'NULL\' ELSE ',
			'CONCAT(\'\\\'\',`', COLUMN_NAME,  '`,\'\\\'\')',
			' END '
			)
  END
   ORDER BY ORDINAL_POSITION 
	),
	')'
  ,',\');\') AS SQL_INSERT FROM `', p_source_table,'` ', p_where , ';'
)
 into v_SQL
	 from information_schema.columns
        where table_schema = DATABASE()
    --    and DATA_TYPE IN ('varchar','char','BLOB','TEXT','SET')
       -- and IS_NULLABLE = 'YES'
       AND NOT((EXTRA LIKE '%auto_increment%' AND p_options LIKE '%-no_identity%' ))
       AND (p_options NOT LIKE CONCAT('%','-exclude:',COLUMN_NAME,'%'))
        and TABLE_NAME = p_source_table
        ORDER BY ORDINAL_POSITION ;
-- -----------

  SET @v_SQL = CONCAT('INSERT INTO `', v_output_table, '` (STATEMENT_TEXT) ' ,v_SQL);

  PREPARE STMT FROM @v_SQL;

  EXECUTE STMT;

-- ----------

-- select v_SQL;
-- select CONCAT(v_CL_SQL,IFNULL(v_result,''),'END');

END $$

DELIMITER ;

