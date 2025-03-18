/****** Object:  StoredProcedure [dbo].[UTLY_GET_REL_TREE]    Script Date: 7/12/2017 9:03:07 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF object_id( 'dbo.UTLY_GET_REL_TREE') IS NULL 
  EXEC sp_executeSql N'CREATE PROCEDURE dbo.UTLY_GET_REL_TREE AS SELECT NULL NILL;';
GO

ALTER PROCEDURE [dbo].[UTLY_GET_REL_TREE] 
          @P_CURRENT_TABLE NVARCHAR(64)
          , @P_ROOT_PATH NVARCHAR(4000)
          , @P_JOIN_PATH NVARCHAR(4000)
          , @P_DEPTH INT
          , @P_LAST_ID NVARCHAR(64)
          , @P_CURRENT_ID NVARChAR(64)
          , @P_LAST_TABLE NVARCHAR(64)
AS
BEGIN

/*
Example:
UTLY_GET_REL_TREE 
                                    'ICS_BASIC_PRMT' -- CURRENT_Table
                                    ,'' -- ROOT_PATH
                                    ,null -- JOIN PATH (root)
                                    ,0 -- DEPTH
                                    ,'' -- LAST_ID
                                    ,'ICS_BASIC_PRMT_ID' -- CURRENT_ID
                                    ,'' -- LAST_TABLE
                                    ;


*/

  SET NOCOUNT ON;
  DECLARE @V_LOOP_COUNT INTEGER;
  DECLARE @V_CURRENT_PK NVARCHAR(64);
  DECLARE @V_NEXT_TABLE NVARCHAR(64);
  DECLARE @V_NEXT_PK_COL NVARCHAR(64);
  DECLARE @V_NEXT_FK_COL NVARCHAR(64);
  DECLARE @V_NEXT_PATH NVARCHAR(500);
  DECLARE @V_NEXT_JOIN_PATH NVARCHAR(4000);
  DECLARE @V_LAST_PK NVARCHAR(64);
  DECLARE @V_CURRENT_ALIAS NVARCHAR(64);
  DECLARE @V_NEXT_DEPTH INTEGER;
  DECLARE @V_LAST_ALIAS NVARCHAR(64);

  
 -- SET @V_CURRENT_PK = @P_CURRENT_TABLE + '_ID'
  SET @V_LOOP_COUNT = 0;

  SET @P_ROOT_PATH = COALESCE(@P_ROOT_PATH,'')
  SET @V_NEXT_PATH = @P_ROOT_PATH + '/' + @P_CURRENT_TABLE;
--  SET @V_LAST_PK = (SELECT ANCESTOR_TABLE_ID from UTLY_REL_TREE WHERE TABLE_PATH = @V_NEXT_PATH AND DEPTH = 1)
 -- SELECT @V_LAST_PK=ANCESTOR_TABLE_ID,@V_CURRENT_PK=TABLE_ID from UTLY_REL_TREE WHERE TABLE_PATH = @V_NEXT_PATH AND DEPTH = 1

          -- table alias is an alias for table_path. 
          -- Get Alias Name as the max number of alias + 1
          SET @V_CURRENT_ALIAS = 
              CASE 
                  WHEN COALESCE(@P_ROOT_PATH,'') = '' THEN @P_CURRENT_TABLE
                  ELSE  
                       SUBSTRING(@P_CURRENT_TABLE,1,1) 
                       + CAST( 
                            (SELECT COALESCE(MAX(cast(SUBSTRING(TABLE_ALIAS,2,4) AS int)),0) + 1 from UTLY_REL_TREE WHERE DEPTH != 0)
                        as VARCHAR)
                        END;


  SET @V_LAST_ALIAS = (SELECT TABLE_ALIAS from UTLY_REL_TREE where TABLE_PATH = @P_ROOT_PATH);

 -- When no join path exists create basic from statement (level = 0)
 -- oterwise, append a new join with 'on' links to the existing one (level > 0)
  IF @P_JOIN_PATH is NULL
    SET @V_NEXT_JOIN_PATH = ' from ' + @P_CURRENT_TABLE + ' ' + @P_CURRENT_TABLE + ' ' + char(13)+char(10)
  ELSE
    SET @V_NEXT_JOIN_PATH = @P_JOIN_PATH + ' JOIN ' + @P_CURRENT_TABLE + ' ' + @V_CURRENT_ALIAS + char(13)+char(10)
       + ' ON ' + @V_CURRENT_ALIAS + '.' + @P_CURRENT_ID 
       + ' = ' + @V_LAST_ALIAS
       + '.' + @P_LAST_ID  + ' ' + char(13)+char(10)
  

 



             insert into UTLY_REL_TREE(TABLE_NAME, ANCESTOR_TABLE_NAME,DEPTH, TABLE_PATH,JOIN_PATH,TABLE_ID,ANCESTOR_TABLE_ID,TABLE_ALIAS)
              VALUES(@P_CURRENT_TABLE,@P_LAST_TABLE,@P_DEPTH,ISNULL(@P_ROOT_PATH,'') + '/' + @P_CURRENT_TABLE, @V_NEXT_JOIN_PATH ,@P_CURRENT_ID, @P_LAST_ID, @V_CURRENT_ALIAS);




WHILE
 (
  select count(*) from UTLY_VW_FK WHERE FK_TABLE_NAME = @P_CURRENT_TABLE
     AND NOT EXISTS (SELECT 1 from UTLY_REL_TREE 
                       WHERE TABLE_PATH = @V_NEXT_PATH + '/' + UTLY_VW_FK.TABLE_NAME)
     AND (@P_CURRENT_TABLE != @P_LAST_TABLE OR TABLE_NAME != @P_CURRENT_TABLE)                  
                       ) > 0
    BEGIN


  
          SELECT TOP 1 @V_NEXT_TABLE=TABLE_NAME,@V_NEXT_PK_COL=COLUMN_NAME, @V_NEXT_FK_COL=FK_COLUMN_NAME 
          from UTLY_VW_FK WHERE FK_TABLE_NAME = @P_CURRENT_TABLE
             AND NOT EXISTS (SELECT 1 from UTLY_REL_TREE 
                       WHERE TABLE_PATH = @V_NEXT_PATH + '/' + UTLY_VW_FK.TABLE_NAME)
             AND (@P_CURRENT_TABLE != @P_LAST_TABLE OR TABLE_NAME != @P_CURRENT_TABLE)                       
                             ;



              SET @V_NEXT_DEPTH = @P_DEPTH  + 1;
     

            exec UTLY_GET_REL_TREE 
                                    @V_NEXT_TABLE -- CURRENT_Table
                                    ,@V_NEXT_PATH -- ROOT_PATH
                                    ,@V_NEXT_JOIN_PATH -- JOIN PATH (root)
                                    ,@V_NEXT_DEPTH -- DEPTH
                                    ,@V_NEXT_FK_COL -- LAST_ID
                                    ,@V_NEXT_PK_COL -- CURRENT_ID
                                    ,@P_CURRENT_TABLE -- LAST_TABLE
                                    ;
                                    

      SET @V_LOOP_COUNT = @V_LOOP_COUNT + 1;
      IF @V_LOOP_COUNT > 200 
        BREAK;
    

    END -- End While...

--  update UTLY_REL_TREE  set JOIN_PATH = (SELECT JOIN_PATH from UTLY_REL_TREE TR0 where TR0.TABLE_PATH = UTLY_REL_TREE.TABLE_PATH and DEPTH = 0)


END -- End procedure


GO
