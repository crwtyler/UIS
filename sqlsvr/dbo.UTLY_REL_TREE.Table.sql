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
