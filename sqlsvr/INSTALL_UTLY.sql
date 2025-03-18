create table UTLY_PARAMETER
(
PARAMETER_NAME VARCHAR(40)
,PARAMETER_VALUE VARCHAR(4000)

);
GO
CREATE TABLE [dbo].[UTLY_REL_TREE](
	[TABLE_NAME] [nvarchar](64) NULL,
	[ANCESTOR_TABLE_NAME] [nvarchar](64) NULL,
	[DEPTH] [int] NULL,
	[TABLE_PATH] [nvarchar](4000) NULL,
	[JOIN_PATH] [nvarchar](4000) NULL,
	[TABLE_ID] [nvarchar](64) NULL,
	[ANCESTOR_TABLE_ID] [nvarchar](64) NULL,
	[TABLE_ALIAS] [nvarchar](64) NULL
)
;
GO


/****** Object:  Table [dbo].[UTLY_SQL_STATEMENTS]    Script Date: 8/9/2017 4:27:55 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[UTLY_SQL_STATEMENTS](
	[STATEMENT_SEQ] [int] IDENTITY(1,1) NOT NULL,
	[STATEMENT_TEXT] [varchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

/****** Object:  View [dbo].[UTLY_VW_FK]    Script Date: 7/12/2017 9:05:08 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create view [dbo].[UTLY_VW_FK]
as
SELECT 
    ccu.table_name AS TABLE_NAME
    ,ccu.constraint_name AS FK_NAME
    ,ccu.column_name AS COLUMN_NAME
    ,kcu.table_name AS FK_TABLE_NAME
    ,kcu.column_name AS FK_COLUMN_NAME
   
FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE ccu
    INNER JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc
        ON ccu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME 
    INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
        ON kcu.CONSTRAINT_NAME = rc.UNIQUE_CONSTRAINT_NAME  

GO


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
/*
Example:
UTLY_GET_REL_TREE_WS 
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
     

            exec UTLY_GET_REL_TREE_WS 
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
-- dbo.UTLY_EXPORT_TO_TABLE 

-- UTILITY Function (Not specific to this database or app)

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF object_id( 'dbo.UTLY_EXPORT_TO_TABLE') IS NULL 
  EXEC sp_executeSql N'CREATE PROCEDURE dbo.UTLY_EXPORT_TO_TABLE AS SELECT NULL NILL;';
GO
-- =============================================
-- MODIFICATION HISTORY
-- Author      Date       Comments
-- ---------   --------   -----------------------------------------------------
-- CTyler      20140328   Created
-- CTyler      20140515   Fixed to work with nulls an varchars, dates, numbers
-- CTyler      20140903   Took out 'TMP'
-- CTyler      20171220   (several name changes before this) and added comments
-- CTyler      20250314   Support Varbinary AND [SCHEMA].[TABLE] notation for table
-- =============================================
ALTER PROCEDURE [dbo].[UTLY_EXPORT_TO_TABLE] (
    @P_TABLE_NAME VARCHAR(128),
    @P_WHERE_CLAUSE VARCHAR(max),
    @P_STATEMENT_TABLE VARCHAR(128) ) AS
BEGIN
  DECLARE @V_STR_INS_FRONT VARCHAR(max);
  DECLARE @V_COMMA CHAR(10);
  DECLARE @V_COL_NAME VARCHAR(128);
  DECLARE @V_COL_TYPE VARCHAR(128);

  DECLARE @V_TABLE_NAME VARCHAR(128);
  DECLARE @V_TABLE_SCHEMA VARCHAR(128);
  
  DECLARE @V_SQL_VALUES_LIST VARCHAR(max); 
  DECLARE @V_SQL_AUTOINS_QUERY NVARCHAR(max);
  
  DECLARE @C_COLUMNS CURSOR;
  DECLARE @C_COLUMNS_STATUS int;
  
/*
USAGE: (note to escape quotes in where statements)

UTLY_EXPORT_TO_TABLE <SOURCE TABLE>, <WHERE Stmt>,<SQL STatement Table>
<Source Table> is where to get the DATABASE
<Where Statement>: Begins with 'WHERE' keyword, must escape quotes, include order by if necessary
<SQL Statement Table>: use UTLY_SQL_STATEMENTS. Table must have 2 column: STATEMENT_SEQ (and autoincrement field) and STATEMENT_TEXT ( long text field for the statement)

Example:
EXEC UTLY_EXPORT_TO_TABLE 'DOC_TMPL','SELECT * FROM DOC_TMPL
WHERE DOC_CATG_ID IN (
SELECT DOC_CATG_ID from DOC_CATG WHERE NAME LIKE ''%(DO NOT USE)%'')', 'UTLY_SQL_STATEMENTS '


Then,
SELECT STATEMENT_TEXT from UTLY_SQL_STATEMENTS order by STATEMENT_SEQ

*/  
  
  -- DECLARE @RET_STAT int;
  
  SET @V_COMMA = '';
  SET @V_SQL_VALUES_LIST = ''

  SET @V_TABLE_NAME = parsename(@P_TABLE_NAME,1);
  SET @V_TABLE_SCHEMA = COALESCE(parsename(@P_TABLE_NAME,2),'dbo');
  
  SET @C_COLUMNS = CURSOR 
  LOCAL STATIC 
  FOR
select COLUMN_NAME, DATA_TYPE
from INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = @V_TABLE_NAME ORDER BY ORDINAL_POSITION
  

SET @V_STR_INS_FRONT = 'INSERT INTO ' + quotename(@V_TABLE_SCHEMA) + '.' + quotename(@V_TABLE_NAME) + ' (';
  
BEGIN TRY

OPEN @C_COLUMNS
FETCH NEXT
FROM @C_COLUMNS INTO @V_COL_NAME,@V_COL_TYPE

WHILE @@FETCH_STATUS = 0
    BEGIN

    
  SET @V_STR_INS_FRONT =  @V_STR_INS_FRONT + @V_COMMA + '[' + @V_COL_NAME  + ']';
  SET @V_COMMA = ',';   

    FETCH NEXT
    FROM @C_COLUMNS INTO @V_COL_NAME,@V_COL_TYPE
    
    IF @@FETCH_STATUS != 0
      BEGIN
        BREAK
      END
 
    
    END

CLOSE @C_COLUMNS


SET @V_STR_INS_FRONT = @V_STR_INS_FRONT + ') ';   

-- PRINT @V_STR_INS_FRONT

END TRY
BEGIN CATCH

SELECT @C_COLUMNS_STATUS = cursor_status('global','@C_COLUMNS')
IF @C_COLUMNS_STATUS > -2
    BEGIN
        DEALLOCATE @C_COLUMNS
    END

    SELECT ERROR_NUMBER() AS ErrorNumber
     ,ERROR_SEVERITY() AS ErrorSeverity
     ,ERROR_STATE() AS ErrorState
     ,ERROR_PROCEDURE() AS ErrorProcedure
     ,ERROR_LINE() AS ErrorLine
     ,ERROR_MESSAGE() AS ErrorMessage;
END CATCH

-- ------------------------
-- Get Value SQL List
-- ------------------------

BEGIN TRY

SET @V_COMMA = '';
OPEN @C_COLUMNS

 FETCH NEXT
  FROM @C_COLUMNS INTO @V_COL_NAME,@V_COL_TYPE

WHILE @@FETCH_STATUS = 0
    BEGIN

-- -------------------------      
-- Assemble Values query   
-- -------------------------
print 'TYPE IS:' + @V_COL_TYPE;
  SET @V_SQL_VALUES_LIST =  @V_SQL_VALUES_LIST + 
    CASE 
	WHEN UPPER(@V_COL_TYPE) IN ('VARCHAR','NVARCHAR','CHAR','TEXT','NTEXT','NCHAR') THEN
         @v_COMMA + '+ CASE WHEN "' + @v_COL_NAME + '" IS NULL THEN  ''null'' ELSE ''''''''+ REPLACE("' + @v_COL_NAME + '",CHAR(39),CHAR(39) + CHAR(39)) +'''''''' END +' 
--         @v_COMMA + '+ CASE WHEN "' + @v_COL_NAME + '" IS NULL THEN  ''null'' ELSE ''''''''+ "' + @v_COL_NAME + '" +'''''''' END +' 
    WHEN UPPER(@V_COL_TYPE) IN ('NUMBER','NUMERIC','BIGINT','INT','MONEY','TINYINT','SMALLMONEY','DECIMAL') THEN
         @V_COMMA + '+ CASE WHEN "' + @V_COL_NAME + '" IS NULL THEN  ''null'' ELSE ''''+ CAST("' + @V_COL_NAME + '" AS VARCHAR) +'''' END +' 
    WHEN UPPER(@V_COL_TYPE) IN ('DATE','DATETIME','DATETIME2','TIME','SMALLDATETIME','DATETIMEOFFSET') THEN
         @V_COMMA + '+ CASE WHEN "' + @V_COL_NAME + '" IS NULL THEN  ''null'' ELSE ''''+ '''''''' + CONVERT(VARCHAR,"' + @V_COL_NAME + '" ,120) + '''''''' +'''' END +' 
    WHEN UPPER(@V_COL_TYPE) IN ('VARBINARY') THEN
         @V_COMMA + '+ CASE WHEN "' + @V_COL_NAME + '" IS NULL THEN  ''null'' ELSE ''CONVERT(varbinary,''''''+ CONVERT(varchar(max),"' + @V_COL_NAME + '" ,1) +'''''',1)'' END +'

    ELSE 
         @V_COMMA + '+ CASE WHEN "' + @V_COL_NAME + '" IS NULL THEN  ''null'' ELSE ''''+ CAST("' + @V_COL_NAME + '" AS VARCHAR) +'''' END +' 
   
    END
     -- The one below replaces null/empty with 'null' but since empty is null in oracle its not needed
    -- v_COMMA + '+ CASE WHEN "' + @v_COL_NAME + '" IS NULL THEN  ''null'' ELSE ''''''''+ "' + @v_COL_NAME + '" +'''''''' END +' 
    -- v_COMMA || '|| CASE WHEN "' || v_COL_NAME || '" IS NULL THEN  ''null'' ELSE ''''''''|| "' || v_COL_NAME || '" ||'''''''' END ||' 
        
    -- The one below was there for an Else... not sure if ever usefull
      --   @V_COMMA + '+''''''''+ "' + @V_COL_NAME  + '"+''''''''+'        
         
SET @V_COMMA = ''',''';


    FETCH NEXT
    FROM @C_COLUMNS INTO @V_COL_NAME,@V_COL_TYPE

    IF @@FETCH_STATUS != 0
      BEGIN
        BREAK
      END
  
 
END 

 -- -----------------------    
  
    
CLOSE @C_COLUMNS


END TRY
BEGIN CATCH

SELECT @C_COLUMNS_STATUS = cursor_status('global','@C_COLUMNS')
IF @C_COLUMNS_STATUS > -2
    BEGIN
        DEALLOCATE @C_COLUMNS
    END

    SELECT ERROR_NUMBER() AS ErrorNumber
     ,ERROR_SEVERITY() AS ErrorSeverity
     ,ERROR_STATE() AS ErrorState
     ,ERROR_PROCEDURE() AS ErrorProcedure
     ,ERROR_LINE() AS ErrorLine
     ,ERROR_MESSAGE() AS ErrorMessage;
END CATCH

DEALLOCATE @C_COLUMNS

-- PRINT ' VALUES: SELECT '' '' ' + @V_SQL_VALUES_LIST + ' '' '' FROM "' + @V_table_name + '" ' + @P_where_clause + ';';

SET @V_SQL_AUTOINS_QUERY = N'SELECT  ''' + REPLACE(@V_STR_INS_FRONT,'''','''''') +' VALUES (''' +  @V_SQL_VALUES_LIST + ' '');'' FROM [' + @V_TABLE_NAME + '] ' + @P_WHERE_CLAUSE + '';

 PRINT @V_SQL_AUTOINS_QUERY;

-- This is for exporting to the screen
--  EXECUTE sp_executesql @V_SQL_AUTOINS_QUERY

SET @V_SQL_AUTOINS_QUERY = 'INSERT INTO [' + @P_STATEMENT_TABLE + '] (STATEMENT_TEXT) ' + @V_SQL_AUTOINS_QUERY

EXECUTE sp_executesql @V_SQL_AUTOINS_QUERY

END
GO


-- UTILITY Function (Not specific to this database or app)

-- Exports data from DB that follows a parent-child structure
/*
Example:
dbo.UTLY_EXPORT_TREE_INSERT 'ICS_BASIC_PRMT','ICS_BASIC_PRMT_ID','WHERE ICS_BASIC_PRMT.ICS_BASIC_PRMT_ID = ''1515266e-9c13-4469-9e8a-ee609c08e7b1'''

select STATEMENT_TEXT from UTLY_SQL_STATEMENTS order by STATEMENT_SEQ;

NOTES:  Be sure to double-quote strins in the where statement (include the word Where),
       Fully Qualify any IDs or stuff in the base table in the where statement.
       
       Statements will come out in order.

*/

IF object_id( 'dbo.UTLY_EXPORT_TREE_INSERT') IS NULL 
  EXEC sp_executeSql N'CREATE PROCEDURE dbo.UTLY_EXPORT_TREE_INSERT AS SELECT NULL NILL;';
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[UTLY_EXPORT_TREE_INSERT] 
           @P_WHERE_CLAUSE VARCHAR(max)

AS
BEGIN
  DECLARE @C_EXPORT_CALLS CURSOR;
  DECLARE @V_TABLE_NAME VARCHAR(64);
  DECLARE @V_TABLE_ID VARCHAR(64);
  DECLARE @V_TABLE_ALIAS VARCHAR(64);
  DECLARE @V_JOIN_PATH VARCHAR(4000);
  DECLARE @V_TABLE_PATH VARCHAR(64);
  DECLARE @V_TABLE_WHERE VARCHAR(4000);
  DECLARE @C_COLUMNS_STATUS int;
    
  
  DECLARE @V_CQ CHAR(1);
  SET @V_CQ = '"';
-- UTILITY Function (Not specific to this database or app)

-- Exports data from DB that follows a parent-child structure
/*
Example:
dbo.UTLY_EXPORT_TREE_INSERT 'ICS_BASIC_PRMT','ICS_BASIC_PRMT_ID','WHERE ICS_BASIC_PRMT.ICS_BASIC_PRMT_ID = ''1515266e-9c13-4469-9e8a-ee609c08e7b1'''

select STATEMENT_TEXT from UTLY_SQL_STATEMENTS order by STATEMENT_SEQ;

NOTES:  Be sure to double-quote strins in the where statement (include the word Where),
       Fully Qualify any IDs or stuff in the base table in the where statement.
       
       Statements will come out in order.

*/

  SET @C_EXPORT_CALLS = CURSOR
  FOR
  SELECT TABLE_NAME, TABLE_ID, TABLE_ALIAS, JOIN_PATH, TABLE_PATH FROM UTLY_REL_TREE order by TABLE_PATH;


  BEGIN TRY

  OPEN @C_EXPORT_CALLS
  FETCH NEXT
  FROM @C_EXPORT_CALLS INTO @V_TABLE_NAME, @V_TABLE_ID, @V_TABLE_ALIAS, @V_JOIN_PATH, @V_TABLE_PATH

  WHILE @@FETCH_STATUS = 0
    BEGIN

    SET @V_TABLE_WHERE = ' WHERE ' + parsename(@V_TABLE_NAME,1) +  '.'+ @V_TABLE_ID  + ' IN (SELECT ' + @V_TABLE_ALIAS + '.' +  @V_TABLE_ID +  ' ' + @V_JOIN_PATH + @P_WHERE_CLAUSE +')';
    print CONCAT(@V_TABLE_PATH,': ', @V_TABLE_NAME, @V_TABLE_WHERE);
    EXEC UTLY_EXPORT_TO_TABLE @V_TABLE_NAME, @V_TABLE_WHERE, 'UTLY_SQL_STATEMENTS';

  --  insert into UTLY_SQL_STATEMENTS (STATEMENT_TEXT) VALUES ( @V_TABLE_WHERE);


    FETCH NEXT
    FROM @C_EXPORT_CALLS INTO @V_TABLE_NAME, @V_TABLE_ID, @V_TABLE_ALIAS, @V_JOIN_PATH, @V_TABLE_PATH
    
    IF @@FETCH_STATUS != 0
      BEGIN
        BREAK
      END --  @@FETCH_STATUS != 0
 
    
    END -- WHILE 



END TRY
BEGIN CATCH
SELECT @C_COLUMNS_STATUS = cursor_status('global','@C_EXPORT_CALLS')
IF @C_COLUMNS_STATUS > -2
    BEGIN
        DEALLOCATE @C_EXPORT_CALLS
    END

    SELECT ERROR_NUMBER() AS ErrorNumber
     ,ERROR_SEVERITY() AS ErrorSeverity
     ,ERROR_STATE() AS ErrorState
     ,ERROR_PROCEDURE() AS ErrorProcedure
     ,ERROR_LINE() AS ErrorLine
     ,ERROR_MESSAGE() AS ErrorMessage;
END CATCH
END


GO



IF object_id( 'dbo.UTLY_EXPORT_TREE_DELETE') IS NULL 
  EXEC sp_executeSql N'CREATE PROCEDURE dbo.UTLY_EXPORT_TREE_DELETE AS SELECT NULL NILL;';
GO

ALTER PROCEDURE [dbo].[UTLY_EXPORT_TREE_DELETE] @P_WHERE VARCHAR(max)
AS
BEGIN

-- UTILITY Function (Not specific to this database or app)
-- Exports delete statements to remove data from tree with Relational Integrety.
-- Call After running UTLY_GET_REL_TREE 
/*
Example:
dbo.UTLY_EXPORT_TREE_DELETE 'WHERE ICS_BASIC_PRMT.ICS_BASIC_PRMT_ID = ''1515266e-9c13-4469-9e8a-ee609c08e7b1'''

select STATEMENT_TEXT from UTLY_SQL_STATEMENTS order by STATEMENT_SEQ;

NOTES:  Be sure to double-singlequote strings in the where statement (start with the word WHERE),
       Fully Qualify any IDs or stuff in the base table in the where statement.
       
       Statements will come out in order.

*/

DECLARE @V_CQ CHAR(1);
DECLARE @V_NEWLINE VARCHAR(2);



SET @V_NEWLINE = CHAR(13);
SET @V_CQ = '"';

insert into UTLY_SQL_STATEMENTS(STATEMENT_TEXT)
select
CONCAT(
'DELETE [',TABLE_ALIAS,'] ' , JOIN_PATH , ' ', @P_WHERE , ';'

)
 from UTLY_REL_TREE order by Depth desc;

end
GO
