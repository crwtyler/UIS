
-- UTLY_GET_REL_TREE.Procedure.sql
-- MySQL
DELIMITER $$

DROP PROCEDURE IF EXISTS `UTLY_GET_REL_TREE` $$
CREATE  PROCEDURE `UTLY_GET_REL_TREE`(
   P_CURRENT_TABLE VARCHAR(64),
   IN P_ROOT_PATH VARCHAR(500),
   IN P_JOIN_PATH VARCHAR(4000),
   IN P_DEPTH INTEGER,
   IN P_LAST_ID VARCHAR(64),
   IN P_CURRENT_ID VARCHAR(64),
   IN P_LAST_TABLE VARCHAR(64)
)
BEGIN

/*
Example:
SET @@SESSION.max_sp_recursion_depth = 100;
call UTLY_GET_REL_TREE('ICS_BASIC_PRMT' -- CURRENT_Table
                                    ,'' -- ROOT_PATH
                                    ,null -- JOIN PATH (root)
                                    ,0 -- DEPTH
                                    ,'' -- LAST_ID
                                    ,'ICS_BASIC_PRMT_ID' -- CURRENT_ID
                                    ,'' -- LAST_TABLE
                                    );


*/

  DECLARE V_LOOP_COUNT INT;
  DECLARE V_CURRENT_PK VARCHAR(64);
  DECLARE V_NEXT_TABLE VARCHAR(64);
  DECLARE V_NEXT_PK_COL VARCHAR(64);
  DECLARE V_NEXT_FK_COL VARCHAR(64);
  DECLARE V_NEXT_PATH VARCHAR(4000);
  DECLARE V_NEXT_JOIN_PATH VARCHAR(4000);
  DECLARE V_LAST_PK VARCHAR(64);
  DECLARE V_CURRENT_ALIAS VARCHAR(64);
  DECLARE V_NEXT_DEPTH INT;
  DECLARE V_LAST_ALIAS VARCHAR(64);
  DECLARE V_NEXT_ALIAS_NUM INT;


  SET V_LOOP_COUNT = 0;
  SET P_ROOT_PATH = COALESCE(P_ROOT_PATH,'');
  SET V_NEXT_PATH = CONCAT(P_ROOT_PATH , '/' , P_CURRENT_TABLE);


  -- get the next alias number if we need it
 IF EXISTS (SELECT 1 from UTLY_REL_TREE where DEPTH != 0) THEN
  SELECT MAX(CAST(COALESCE(NULLIF(SUBSTRING(TABLE_ALIAS,2,4),''),0) as UNSIGNED)) + 1  INTO V_NEXT_ALIAS_NUM from UTLY_REL_TREE WHERE DEPTH != 0;
 ELSE
   SET V_NEXT_ALIAS_NUM = 0;
 END IF;

  -- table alias is an alias for table_path.
  -- Get Alias Name as the max number of alias + 1
  SET V_CURRENT_ALIAS =
      CASE
          WHEN COALESCE(P_ROOT_PATH,'') = '' THEN P_CURRENT_TABLE
           ELSE
              CONCAT(SUBSTRING(P_CURRENT_TABLE,1,1),cast(V_NEXT_ALIAS_NUM as CHAR))
      END;

  SELECT TABLE_ALIAS INTO V_LAST_ALIAS from UTLY_REL_TREE where TABLE_PATH = P_ROOT_PATH;


 -- When no join path exists create basic from statement (level = 0)
 -- oterwise, append a new join with 'on' links to the existing one (level > 0)
  IF P_JOIN_PATH IS NULL THEN
    SET V_NEXT_JOIN_PATH = concat(' from `' , P_CURRENT_TABLE , '` ' , char(13),char(10));
  ELSE
    SET V_NEXT_JOIN_PATH = CONCAT(
      P_JOIN_PATH , ' JOIN `' , P_CURRENT_TABLE ,'` ',V_CURRENT_ALIAS , char(13),char(10)
         , ' ON ' , V_CURRENT_ALIAS , '.`' , P_CURRENT_ID
         , '` = ' , V_LAST_ALIAS
         , '.`' , P_LAST_ID  , '` ' , char(13),char(10)
      );
  END IF;



  insert into UTLY_REL_TREE(TABLE_NAME, ANCESTOR_TABLE_NAME,DEPTH, TABLE_PATH,JOIN_PATH,TABLE_ID,ANCESTOR_TABLE_ID,TABLE_ALIAS)
  VALUES(P_CURRENT_TABLE,P_LAST_TABLE,P_DEPTH,concat(IFNULL(P_ROOT_PATH,'') , '/' , P_CURRENT_TABLE), V_NEXT_JOIN_PATH ,P_CURRENT_ID, P_LAST_ID, V_CURRENT_ALIAS);

mainloop: WHILE
  (
  select count(*) from UTLY_VW_FK VFK WHERE FK_TABLE_NAME = P_CURRENT_TABLE
     AND NOT EXISTS (SELECT 1 from UTLY_REL_TREE
                       WHERE TABLE_PATH = CONCAT(V_NEXT_PATH , '/' , VFK.TABLE_NAME) )
     AND (P_CURRENT_TABLE != P_LAST_TABLE OR TABLE_NAME != P_CURRENT_TABLE)
  ) > 0 DO


          SELECT VFK.TABLE_NAME,VFK.COLUMN_NAME,VFK.FK_COLUMN_NAME INTO V_NEXT_TABLE,V_NEXT_PK_COL,V_NEXT_FK_COL
          from UTLY_VW_FK VFK WHERE FK_TABLE_NAME = P_CURRENT_TABLE
             AND NOT EXISTS (SELECT 1 from UTLY_REL_TREE
                       WHERE TABLE_PATH = CONCAT(V_NEXT_PATH , '/' , VFK.TABLE_NAME))
             AND (P_CURRENT_TABLE != P_LAST_TABLE OR TABLE_NAME != P_CURRENT_TABLE) LIMIT 1;


              SET V_NEXT_DEPTH = P_DEPTH  + 1;

            call UTLY_GET_REL_TREE
                                    (V_NEXT_TABLE -- CURRENT_Table
                                    ,V_NEXT_PATH -- ROOT_PATH
                                    ,V_NEXT_JOIN_PATH -- JOIN PATH (root)
                                    ,V_NEXT_DEPTH -- DEPTH
                                    ,V_NEXT_FK_COL -- LAST_ID
                                    ,V_NEXT_PK_COL -- CURRENT_ID
                                    ,P_CURRENT_TABLE -- LAST_TABLE
                                    );



      SET V_LOOP_COUNT = V_LOOP_COUNT + 1;
      IF V_LOOP_COUNT > 100 THEN
        LEAVE mainloop;
      END IF;


END WHILE;


 -- update UTLY_REL_TREE  set JOIN_PATH = (SELECT JOIN_PATH from (SELECT * FROM UTLY_REL_TREE) TR0 where TR0.TABLE_PATH = UTLY_REL_TREE.TABLE_PATH and DEPTH = 0);
 -- COMMIT;

END $$

DELIMITER ;

