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
-- 2025-03-17 CRT: Fix to work with schemas
-- 2025-03-29 CRT: cleanup
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

  DECLARE @V_CURRENT_TABLE NVARCHAR(64);
  DECLARE @V_CURRENT_SCHEMA NVARCHAR(64);
  DECLARE @V_SCHEMATABLE_QTED NVARCHAR(129);

    DECLARE @V_LAST_TABLE NVARCHAR(64);
  DECLARE @V_LAST_SCHEMA NVARCHAR(64);
  DECLARE @V_LAST_SCHEMATABLE_QTED NVARCHAR(129);

  SET @V_CURRENT_TABLE = parsename(@P_CURRENT_TABLE,1);
  SET @V_CURRENT_SCHEMA = COALESCE(parsename(@P_CURRENT_TABLE,2),'dbo');
  SET @V_SCHEMATABLE_QTED = CONCAT(quotename(@V_CURRENT_SCHEMA),'.',quotename(@V_CURRENT_TABLE));
  
  SET @V_LAST_TABLE = parsename(@P_LAST_TABLE,1);
  SET @V_LAST_SCHEMA = case when len(@P_LAST_TABLE) = 0 then '' else COALESCE(parsename(@P_LAST_TABLE,2),'dbo') END;
  SET @V_LAST_SCHEMATABLE_QTED = case when len(@P_LAST_TABLE) = 0 then '' else CONCAT(quotename(@V_LAST_SCHEMA),'.',quotename(@V_LAST_TABLE)) END;
  


 -- SET @V_CURRENT_PK = @V_CURRENT_TABLE + '_ID'
  SET @V_LOOP_COUNT = 0;

  SET @P_ROOT_PATH = COALESCE(@P_ROOT_PATH,'')
  SET @V_NEXT_PATH = @P_ROOT_PATH + '/' + @V_SCHEMATABLE_QTED;
--  SET @V_LAST_PK = (SELECT ANCESTOR_TABLE_ID from UTLY_REL_TREE WHERE TABLE_PATH = @V_NEXT_PATH AND DEPTH = 1)
 -- SELECT @V_LAST_PK=ANCESTOR_TABLE_ID,@V_CURRENT_PK=TABLE_ID from UTLY_REL_TREE WHERE TABLE_PATH = @V_NEXT_PATH AND DEPTH = 1

          -- table alias is an alias for table_path. 
          -- Get Alias Name as the max number of alias + 1
          SET @V_CURRENT_ALIAS = 
              CASE 
                  WHEN COALESCE(@P_ROOT_PATH,'') = '' THEN @V_CURRENT_TABLE
                  ELSE  
                       SUBSTRING(@V_CURRENT_TABLE,1,1) 
                       + CAST( 
                            (SELECT COALESCE(MAX(cast(SUBSTRING(TABLE_ALIAS,2,4) AS int)),0) + 1 from UTLY_REL_TREE WHERE DEPTH != 0)
                        as VARCHAR)
                        END;


  SET @V_LAST_ALIAS = (SELECT TABLE_ALIAS from UTLY_REL_TREE where TABLE_PATH = @P_ROOT_PATH);

 -- When no join path exists create basic from statement (level = 0)
 -- oterwise, append a new join with 'on' links to the existing one (level > 0)
  IF @P_JOIN_PATH is NULL
    SET @V_NEXT_JOIN_PATH = ' from ' + @V_SCHEMATABLE_QTED + ' [' + @V_CURRENT_TABLE + '] ' + char(13)+char(10)
  ELSE
    SET @V_NEXT_JOIN_PATH = @P_JOIN_PATH + ' JOIN ' + @V_SCHEMATABLE_QTED + ' ' + quotename(@V_CURRENT_ALIAS) + char(13)+char(10)
       + ' ON ' + quotename(@V_CURRENT_ALIAS) + '.' + quotename(@P_CURRENT_ID )
       + ' = ' + quotename(@V_LAST_ALIAS)
       + '.' + quotename(@P_LAST_ID)  + ' ' + char(13)+char(10)
  

insert into UTLY_REL_TREE (
	TABLE_NAME
	, ANCESTOR_TABLE_NAME
	,DEPTH
	, TABLE_PATH
	,JOIN_PATH
	,TABLE_ID
	,ANCESTOR_TABLE_ID
	,TABLE_ALIAS
)
VALUES(
	@V_SCHEMATABLE_QTED
	,@V_LAST_SCHEMATABLE_QTED
	,@P_DEPTH
	,ISNULL(@P_ROOT_PATH,'') + '/' + @V_SCHEMATABLE_QTED
	, @V_NEXT_JOIN_PATH 
	,@P_CURRENT_ID
	, @P_LAST_ID
	, @V_CURRENT_ALIAS
);
print concat('Inserted Depth:' ,@P_DEPTH);


WHILE
 (
  select count(*) from UTLY_VW_FK VFK
  WHERE concat(quotename(FK_SCHEMA_NAME),'.',quotename(FK_TABLE_NAME)) = @V_SCHEMATABLE_QTED
     AND NOT EXISTS (SELECT 1 from UTLY_REL_TREE 
                       WHERE TABLE_PATH = @V_NEXT_PATH + '/' + concat(quotename(VFK.SCHEMA_NAME),'.',quotename(VFK.TABLE_NAME)) )
     AND (@V_SCHEMATABLE_QTED != @V_LAST_SCHEMATABLE_QTED OR concat(quotename(SCHEMA_NAME),'.',quotename(TABLE_NAME)) != @V_SCHEMATABLE_QTED)                  
                       ) > 0
    BEGIN

  
          SELECT TOP 1 
			@V_NEXT_TABLE=concat(quotename(SCHEMA_NAME),'.',quotename(TABLE_NAME))
			,@V_NEXT_PK_COL=COLUMN_NAME
			, @V_NEXT_FK_COL=FK_COLUMN_NAME 
          from UTLY_VW_FK VFK
		  WHERE 
			concat(quotename(FK_SCHEMA_NAME),'.',quotename(FK_TABLE_NAME)) = @V_SCHEMATABLE_QTED
             AND NOT EXISTS (
						SELECT 1 from UTLY_REL_TREE 
						WHERE TABLE_PATH = @V_NEXT_PATH + '/' + concat(quotename(VFK.SCHEMA_NAME),'.',quotename(VFK.TABLE_NAME))
					 )
     AND (@V_SCHEMATABLE_QTED != @V_LAST_SCHEMATABLE_QTED OR concat(quotename(SCHEMA_NAME),'.',quotename(TABLE_NAME)) != @V_SCHEMATABLE_QTED)                        
    ;
 
print '@V_SCHEMATABLE_QTED:' + @V_SCHEMATABLE_QTED
print '@V_NEXT_TABLE:' + @V_NEXT_TABLE -- Table Name (current) for run being called
print '@V_NEXT_PATH:' + @V_NEXT_PATH -- ROOT_PATH
print '@V_NEXT_JOIN_PATH:' + @V_NEXT_JOIN_PATH -- JOIN PATH (root)
print concat('@V_NEXT_DEPTH:' , @V_NEXT_DEPTH) -- DEPTH
print '@V_NEXT_FK_COL:' + @V_NEXT_FK_COL -- LAST_ID
print '@V_NEXT_PK_COL:' + @V_NEXT_PK_COL -- CURRENT_ID
print '@V_CURRENT_TABLE:' + @V_CURRENT_TABLE -- LAST_TABLE




              SET @V_NEXT_DEPTH = @P_DEPTH  + 1;
     

            exec UTLY_GET_REL_TREE 
                                    @V_NEXT_TABLE -- CURRENT_Table
                                    ,@V_NEXT_PATH -- ROOT_PATH
                                    ,@V_NEXT_JOIN_PATH -- JOIN PATH (root)
                                    ,@V_NEXT_DEPTH -- DEPTH
                                    ,@V_NEXT_FK_COL -- LAST_ID
                                    ,@V_NEXT_PK_COL -- CURRENT_ID
                                    ,@V_CURRENT_TABLE -- LAST_TABLE
                                    ;
                                    

      SET @V_LOOP_COUNT = @V_LOOP_COUNT + 1;
      IF @V_LOOP_COUNT > 200 
        BREAK;
    

    END -- End While...

--  update UTLY_REL_TREE  set JOIN_PATH = (SELECT JOIN_PATH from UTLY_REL_TREE TR0 where TR0.TABLE_PATH = UTLY_REL_TREE.TABLE_PATH and DEPTH = 0)


END -- End procedure

GO
