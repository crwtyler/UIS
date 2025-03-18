create or replace procedure SP_GET_TABLE_RELATE (
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
call SP_GET_TABLE_RELATE('ICS_BASIC_PRMT' -- CURRENT_Table
                                    ,'' -- ROOT_PATH
                                    ,null -- JOIN PATH (root)
                                    ,0 -- DEPTH
                                    ,'' -- LAST_ID
                                    ,'ICS_BASIC_PRMT_ID' -- CURRENT_ID
                                    ,'' -- LAST_TABLE
                                    );
*/
V_LOOP_COUNT INTEGER;
V_CURRENT_PK VARCHAR(64);
V_NEXT_TABLE VARCHAR(64);
V_NEXT_PK_COL VARCHAR(64);
V_NEXT_FK_COL VARCHAR(64);
V_NEXT_PATH VARCHAR(500);
V_NEXT_JOIN_PATH VARCHAR(4000);
V_LAST_PK VARCHAR(64);
V_LAST_TABLE VARCHAR(64);
V_CUR_COUNT INTEGER;
V_ROOT_PATH VARCHAR(64);
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
  SELECT COALESCE(MAX(cast(SUBSTR(TABLE_ALIAS,2,2) AS INTEGER)),0) + 1 INTO V_NEXT_ALIAS_NUM from TRACK_RELATE WHERE DEPTH != 0;

  -- table alias is an alias for table_path.
  -- Get Alias Name as the max number of alias + 1
  V_CURRENT_ALIAS :=
      CASE
          WHEN COALESCE(P_ROOT_PATH,'') = '' THEN P_CURRENT_TABLE
           ELSE
              SUBSTR(P_CURRENT_TABLE,1,1) || CAST(V_NEXT_ALIAS_NUM as varchar)
      END;
     
SELECT count(*) INTO V_RP_COUNT from TRACK_RELATE where TABLE_PATH = P_ROOT_PATH;     
      
IF V_RP_COUNT > 0 THEN
  SELECT TABLE_ALIAS INTO V_LAST_ALIAS from TRACK_RELATE where TABLE_PATH = P_ROOT_PATH;
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
    
             insert into TRACK_RELATE(TABLE_NAME, ANCESTOR_TABLE_NAME,DEPTH, TABLE_PATH,JOIN_PATH,TABLE_ID,ANCESTOR_TABLE_ID,TABLE_ALIAS)
             VALUES(P_CURRENT_TABLE,P_LAST_TABLE,P_DEPTH,COALESCE(P_ROOT_PATH,'') || '/' || P_CURRENT_TABLE,V_NEXT_JOIN_PATH,P_CURRENT_ID, P_LAST_ID, V_CURRENT_ALIAS );


  SELECT COUNT(*) into V_CUR_COUNT from VW_UTIL_FK VFK WHERE FK_TABLE_NAME = P_CURRENT_TABLE
     AND NOT EXISTS (SELECT 1 from TRACK_RELATE
                       WHERE TABLE_PATH = V_NEXT_PATH || '/' || VFK.TABLE_NAME)
     AND (P_CURRENT_TABLE != P_LAST_TABLE OR TABLE_NAME != P_CURRENT_TABLE)                  
                       ;

WHILE V_CUR_COUNT > 0
    LOOP
    
          SELECT VFK.TABLE_NAME,VFK.COLUMN_NAME,VFK.FK_COLUMN_NAME INTO V_NEXT_TABLE,V_NEXT_PK_COL,V_NEXT_FK_COL 
          from VW_UTIL_FK VFK WHERE FK_TABLE_NAME = P_CURRENT_TABLE
     AND NOT EXISTS (SELECT 1 from TRACK_RELATE
                       WHERE TABLE_PATH = V_NEXT_PATH || '/' || VFK.TABLE_NAME)
     AND (P_CURRENT_TABLE != P_LAST_TABLE OR TABLE_NAME != P_CURRENT_TABLE)                  
             and rownum = 1;

    V_NEXT_DEPTH := P_DEPTH  + 1;
 
             SP_GET_TABLE_RELATE(V_NEXT_TABLE
                                    ,V_NEXT_PATH 
                                    ,V_NEXT_JOIN_PATH 
                                    ,V_NEXT_DEPTH 
                                    ,V_NEXT_FK_COL 
                                    ,V_NEXT_PK_COL 
                                    ,P_CURRENT_TABLE 
                                    );




      commit;
      
      V_LOOP_COUNT := V_LOOP_COUNT + 1;
      IF V_LOOP_COUNT > 10 THEN
        EXIT;
      END IF;
  SELECT COUNT(*) into V_CUR_COUNT from VW_UTIL_FK VFK WHERE FK_TABLE_NAME = P_CURRENT_TABLE
     AND NOT EXISTS (SELECT 1 from TRACK_RELATE
                       WHERE TABLE_PATH = V_NEXT_PATH || '/' || VFK.TABLE_NAME)
     AND (P_CURRENT_TABLE != P_LAST_TABLE OR TABLE_NAME != P_CURRENT_TABLE)
     ;

    END LOOP; -- End While...

  -- put the join criteria on all by table path (only calculated at 0 depth)
 -- update TRACK_RELATE  set JOIN_PATH = (SELECT JOIN_PATH from TRACK_RELATE TR0 where TR0.TABLE_PATH = TRACK_RELATE.TABLE_PATH and DEPTH = 0  and rownum=1);

commit; 

END;
