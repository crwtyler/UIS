
IF object_id( 'dbo.UTLY_DELETE_TREE_TO_TABLE') IS NULL 
  EXEC sp_executeSql N'CREATE PROCEDURE dbo.UTLY_DELETE_TREE_TO_TABLE AS SELECT NULL NILL;';
GO

ALTER PROCEDURE UTLY_DELETE_TREE_TO_TABLE @P_WHERE VARCHAR(max)
AS
BEGIN

-- UTILITY Function (Not specific to this database or app)
-- Exports delete statements to remove data from tree with Relational Integrety.
-- Call After running UTLY_GET_REL_TREE 
/*
Example:
dbo.UTLY_DELETE_TREE_TO_TABLE 'ICS_BASIC_PRMT','WHERE ICS_BASIC_PRMT.ICS_BASIC_PRMT_ID = ''1515266e-9c13-4469-9e8a-ee609c08e7b1'''

select STATEMENT_TEXT from UTLY_SQL_STATEMENTS order by STATEMENT_SEQ;

NOTES:  Be sure to double-quote strins in the where statement (include the word Where),
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
'DELETE ',TABLE_ALIAS,' ' , JOIN_PATH , ' ', @P_WHERE , ';'

)
 from UTLY_REL_TREE order by Depth desc;

end
GO
