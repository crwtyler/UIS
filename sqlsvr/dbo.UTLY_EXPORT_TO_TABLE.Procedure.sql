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

