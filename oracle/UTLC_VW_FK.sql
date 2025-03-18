
  CREATE OR REPLACE FORCE VIEW "ICS_FLOW_LOCAL"."UTLC_VW_FK" ("TABLE_NAME", "COLUMN_NAME", "FK_NAME", "FK_TABLE_NAME", "FK_COLUMN_NAME") AS 
  select
    col.table_name AS TABLE_NAME,
    col.column_name as COLUMN_NAME,    
    cc.constraint_name as FK_NAME,
    rel.table_name AS FK_TABLE_NAME,
    rel.column_name as FK_COLUMN_NAME
from
    user_tab_columns col
    join user_cons_columns con 
      on col.table_name = con.table_name 
     and col.column_name = con.column_name
    join user_constraints cc 
      on con.constraint_name = cc.constraint_name
    join user_cons_columns rel 
      on cc.r_constraint_name = rel.constraint_name 
     and con.position = rel.position
where
    cc.constraint_type = 'R';
 
