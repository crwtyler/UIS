
-- UTILITY Function (Not specific to this database or app)

-- DELETEs data from DB that follows a parent-child structure
/*
Example:
dbo.UTLY_DELETE_TREE 'ICS_BASIC_PRMT','ICS_BASIC_PRMT_ID','WHERE ICS_BASIC_PRMT.ICS_BASIC_PRMT_ID = ''1515266e-9c13-4469-9e8a-ee609c08e7b1'''

select STATEMENT_TEXT from UTLY_SQL_STATEMENTS order by STATEMENT_SEQ;

NOTES:  Be sure to double-quote strins in the where statement (include the word Where),
       Fully Qualify any IDs or stuff in the base table in the where statement.
       
       Statements will come out in order.

*/

DELIMITER $$

DROP PROCEDURE IF EXISTS UTLY_DELETE_TREE $$

CREATE PROCEDURE UTLY_DELETE_TREE
(
          @P_ROOT_TABLE NVARCHAR(64)
          ,@P_ROOT_TABLE_ID NVARCHAR(64)
          , @P_WHERE_CLAUSE VARCHAR(max)
)
AS
BEGIN
  DECLARE @C_DELETE_CALLS CURSOR;
  DECLARE @V_TABLE_NAME VARCHAR(64);
  DECLARE @V_TABLE_ID VARCHAR(64);
  DECLARE @V_TABLE_ALIAS VARCHAR(64);
  DECLARE @V_JOIN_PATH VARCHAR(4000);
  DECLARE @V_TABLE_PATH VARCHAR(64);
  DECLARE @V_TABLE_WHERE VARCHAR(4000);
  DECLARE @C_COLUMNS_STATUS int;
  DECLARE @V_DELETE_STMT VARCHAR(4000);
-- UTILITY Function (Not specific to this database or app)

-- DELETEs data from DB that follows a parent-child structure
/*
Example:
dbo.UTLY_DELETE_TREE 'ICS_BASIC_PRMT','ICS_BASIC_PRMT_ID','WHERE ICS_BASIC_PRMT.ICS_BASIC_PRMT_ID = ''1515266e-9c13-4469-9e8a-ee609c08e7b1'''

select STATEMENT_TEXT from UTLY_SQL_STATEMENTS order by STATEMENT_SEQ;

NOTES:  Be sure to double-quote strins in the where statement (include the word Where),
       Fully Qualify any IDs or stuff in the base table in the where statement.
       
       Statements will come out in order.

*/

  SET @C_DELETE_CALLS = CURSOR
  FOR
  SELECT TABLE_NAME, TABLE_ID, TABLE_ALIAS, JOIN_PATH, TABLE_PATH FROM UTLY_REL_TREE order by TABLE_PATH DESC;

  delete from UTLY_REL_TREE;

exec UTLY_GET_REL_TREE 
                                    @P_ROOT_TABLE -- CURRENT_Table
                                    ,'' -- ROOT_PATH
                                    ,null -- JOIN PATH (root)
                                    ,0 -- DEPTH
                                    ,'' -- LAST_ID
                                    ,@P_ROOT_TABLE_ID -- CURRENT_ID
                                    ,'' -- LAST_TABLE
                                    ;

DELETE from UTLY_SQL_STATEMENTS;


  BEGIN TRY

  OPEN @C_DELETE_CALLS
  FETCH NEXT
  FROM @C_DELETE_CALLS INTO @V_TABLE_NAME, @V_TABLE_ID, @V_TABLE_ALIAS, @V_JOIN_PATH, @V_TABLE_PATH

  WHILE @@FETCH_STATUS = 0
    BEGIN

    SET @V_TABLE_WHERE = ' WHERE ' + @V_TABLE_NAME + '.' + @V_TABLE_ID + ' IN (SELECT ' + @V_TABLE_ALIAS + '.' + @V_TABLE_ID + ' ' + @V_JOIN_PATH + @P_WHERE_CLAUSE +')';

   -- EXEC UTLY_DELETE_TO_TABLE @V_TABLE_NAME, @P_WHERE_CLAUSE, 'UTLY_SQL_STATEMENTS';
    SET @V_DELETE_STMT = 'DELETE FROM "' + @V_TABLE_NAME + '" ' + @V_TABLE_WHERE;
    insert into UTLY_SQL_STATEMENTS (STATEMENT_TEXT) VALUES ( @V_DELETE_STMT);


    FETCH NEXT
    FROM @C_DELETE_CALLS INTO @V_TABLE_NAME, @V_TABLE_ID, @V_TABLE_ALIAS, @V_JOIN_PATH, @V_TABLE_PATH
    
    IF @@FETCH_STATUS != 0
      BEGIN
        BREAK
      END --  @@FETCH_STATUS != 0
 
    
    END -- WHILE 



END TRY
BEGIN CATCH
SELECT @C_COLUMNS_STATUS = cursor_status('global','@C_DELETE_CALLS')
IF @C_COLUMNS_STATUS > -2
    BEGIN
        DEALLOCATE @C_DELETE_CALLS
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


