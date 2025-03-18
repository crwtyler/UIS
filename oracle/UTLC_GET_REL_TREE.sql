create or replace procedure UTLC_GET_REL_TREE (
    P_CURRENT_TABLE IN VARCHAR
    ,P_ROOT_PATH IN VARCHAR
    ,P_JOIN_PATH IN VARCHAR
    ,P_DEPTH INTEGER
    ,P_LAST_ID VARCHAR
    ,P_CURRENT_ID VARCHAR
    ,P_LAST_TABLE VARCHAR
    )
AS
/*
example:
exec UTLC_GET_REL_TREE('ICS_BASIC_PRMT','' ,null,0 ,'','ICS_BASIC_PRMT_ID','');
*/
V_LOOP_COUNT INTEGER;
V_CURRENT_PK VARCHAR(64);
V_NEXT_TABLE VARCHAR(64);
V_NEXT_PK_COL VARCHAR(64);
V_NEXT_FK_COL VARCHAR(64);
V_NEXT_PATH VARCHAR(4000);
V_NEXT_JOIN_PATH VARCHAR(4000);
V_LAST_PK VARCHAR(64);
V_LAST_TABLE VARCHAR(64);
V_CUR_COUNT INTEGER;
V_ROOT_PATH VARCHAR(4000);
V_TEST_COUNT INTEGER;
V_CURRENT_ALIAS VARCHAR(64);
V_NEXT_DEPTH INTEGER;
V_LAST_ALIAS VARCHAR(64);
V_NEXT_ALIAS_NUM INTEGER;
V_RP_COUNT INTEGER;

BEGIN


  V_LOOP_COUNT := 0;

  V_ROOT_PATH := COALESCE(P_ROOT_PATH,'');
  V_NEXT_PATH := V_ROOT_PATH || '/' || P_CURRENT_TABLE;


  -- get the next alias number if we need it
  SELECT COALESCE(MAX(cast(SUBSTR(TABLE_ALIAS,2,4) AS INTEGER)),0) + 1 INTO V_NEXT_ALIAS_NUM from UTLC_REL_TREE WHERE DEPTH != 0;

  -- table alias is an alias for table_path.
  -- Get Alias Name as the max number of alias + 1
  IF P_JOIN_PATH is NULL THEN  
     V_CURRENT_ALIAS := P_CURRENT_TABLE;
  ELSE 
     V_CURRENT_ALIAS := SUBSTR(P_CURRENT_TABLE,1,1) || CAST(V_NEXT_ALIAS_NUM as varchar);
  END IF;
     
SELECT count(*) INTO V_RP_COUNT from UTLC_REL_TREE where TABLE_PATH = P_ROOT_PATH;     
      
IF V_RP_COUNT > 0 THEN
  SELECT TABLE_ALIAS INTO V_LAST_ALIAS from UTLC_REL_TREE where TABLE_PATH = P_ROOT_PATH;
END IF;
 -- When no join path exists create basic from statement (level = 0)
 -- oterwise, append a new join with 'on' links to the existing one (level > 0)   

  IF P_JOIN_PATH is NULL THEN
    V_NEXT_JOIN_PATH := ' from ' || P_CURRENT_TABLE || ' ' || chr(13)||chr(10);
  ELSE
    V_NEXT_JOIN_PATH := P_JOIN_PATH || ' JOIN ' || P_CURRENT_TABLE ||' ' || V_CURRENT_ALIAS || chr(13)||chr(10)
       || ' ON ' || V_CURRENT_ALIAS || '.' || P_CURRENT_ID 
       || ' = ' || V_LAST_ALIAS
       || '.' || P_LAST_ID  || ' ' || chr(13) || chr(10);
    END IF;
    
             insert into UTLC_REL_TREE(TABLE_NAME, ANCESTOR_TABLE_NAME,DEPTH, TABLE_PATH,JOIN_PATH,TABLE_ID,ANCESTOR_TABLE_ID,TABLE_ALIAS)
             VALUES(P_CURRENT_TABLE,P_LAST_TABLE,P_DEPTH,COALESCE(P_ROOT_PATH,'') || '/' || P_CURRENT_TABLE,V_NEXT_JOIN_PATH,P_CURRENT_ID, P_LAST_ID, V_CURRENT_ALIAS );


  SELECT COUNT(*) into V_CUR_COUNT from UTLC_VW_FK VFK WHERE FK_TABLE_NAME = P_CURRENT_TABLE
     AND NOT EXISTS (SELECT 1 from UTLC_REL_TREE
                       WHERE TABLE_PATH = V_NEXT_PATH || '/' || VFK.TABLE_NAME)
     AND (P_CURRENT_TABLE != P_LAST_TABLE OR TABLE_NAME != P_CURRENT_TABLE)                  
                       ;

WHILE V_CUR_COUNT > 0
    LOOP
    
          SELECT VFK.TABLE_NAME,VFK.COLUMN_NAME,VFK.FK_COLUMN_NAME INTO V_NEXT_TABLE,V_NEXT_PK_COL,V_NEXT_FK_COL 
          from UTLC_VW_FK VFK WHERE FK_TABLE_NAME = P_CURRENT_TABLE
     AND NOT EXISTS (SELECT 1 from UTLC_REL_TREE
                       WHERE TABLE_PATH = V_NEXT_PATH || '/' || VFK.TABLE_NAME)
     AND (P_CURRENT_TABLE != P_LAST_TABLE OR TABLE_NAME != P_CURRENT_TABLE)                  
             and rownum = 1;

    V_NEXT_DEPTH := P_DEPTH  + 1;
 
             UTLC_GET_REL_TREE(V_NEXT_TABLE
                                    ,V_NEXT_PATH 
                                    ,V_NEXT_JOIN_PATH 
                                    ,V_NEXT_DEPTH 
                                    ,V_NEXT_FK_COL 
                                    ,V_NEXT_PK_COL 
                                    ,P_CURRENT_TABLE 
                                    );




      commit;
      
      V_LOOP_COUNT := V_LOOP_COUNT + 1;
      IF V_LOOP_COUNT > 200 THEN
        EXIT;
      END IF;
  SELECT COUNT(*) into V_CUR_COUNT from UTLC_VW_FK VFK WHERE FK_TABLE_NAME = P_CURRENT_TABLE
     AND NOT EXISTS (SELECT 1 from UTLC_REL_TREE
                       WHERE TABLE_PATH = V_NEXT_PATH || '/' || VFK.TABLE_NAME)
     AND (P_CURRENT_TABLE != P_LAST_TABLE OR TABLE_NAME != P_CURRENT_TABLE)
     ;

    END LOOP; -- End While...

  -- put the join criteria on all by table path (only calculated at 0 depth)
 -- update UTLC_REL_TREE  set JOIN_PATH = (SELECT JOIN_PATH from UTLC_REL_TREE TR0 where TR0.TABLE_PATH = UTLC_REL_TREE.TABLE_PATH and DEPTH = 0  and rownum=1);

commit; 

END;
