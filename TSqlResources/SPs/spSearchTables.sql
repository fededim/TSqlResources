/*********************************************************************************************
© 2023	Federico Di Marco <fededim@gmail.com>
spSearchTables - A helper stored procedure which allows to search tables or columns either by name or by value in all databases in a server

PARAMETERS:
	- @dbSearchPattern: a SQL LIKE pattern to filter databases, set to NULL to search in all databases
	- @tableSearchPattern: a SQL LIKE pattern to filter tables, set to  NULL to search in all tables
	- @columnSearchPattern: a SQL LIKE pattern to filter columns, set to NULL to peform search only on tables, set to '%' to search also on all columns
	- @valuePattern: a SQL LIKE pattern to filter column value, set to NULL to not to search on column values
 
OUTPUT:
	- A result table

VERSION HISTORY:
  20231021	fededim		Initial Release
 
*********************************************************************************************/

CREATE OR ALTER PROCEDURE spSearchTables
(@dbSearchPattern nvarchar(256)=NULL, 
 @tableSearchPattern nvarchar(256),
 @columnSearchPattern nvarchar(256)=NULL,
 @valuePattern nvarchar(1000)=NULL)
AS
BEGIN

SET CONCAT_NULL_YIELDS_NULL OFF

-- Create output temporary table
CREATE TABLE #Output
(
 [Database] nvarchar(100),
 [Schema] nvarchar(100),
 [Table] nvarchar(100),
 [Column] nvarchar(100),
 [FullTableName] nvarchar(300),
 [FullSelect] nvarchar(300),
)

DECLARE @outerDbName nvarchar(100)

DECLARE @statement NVARCHAR(MAX) = N'
USE [?]


DECLARE @dbName nvarchar(200), @schemaName nvarchar(200),@tableName nvarchar(200), @columnName nvarchar(200), @columnType nvarchar(200), @fullTableName nvarchar(1000), @sql nvarchar(4000), @selectSql nvarchar(4000)

PRINT N''Checking database [?]''

DECLARE [tables] CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR
SELECT N''[''+ DB_NAME() +N'']'' AS DatabaseName,N''[''+ s.[name] +N'']'' AS SchemaName,N''[''+ t.[name] +N'']'' AS TableName,IIF(c.[name] IS NOT NULL,N''[''+ c.[name] +N'']'',NULL) AS ColumnName,tp.[Name] AS ColumnType, N''[''+DB_NAME()+N''].[''+s.[name]+N''].[''+t.[name]+N'']'' AS FullTableName
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id=s.schema_id'+
+CHAR(10)+IIF(@columnSearchPattern IS NOT NULL,'INNER','LEFT')+' JOIN sys.columns c ON c.[name] LIKE '''+COALESCE(@columnSearchPattern,'')+''' AND c.[object_id]=t.[object_id]'
+CHAR(10)+'LEFT JOIN sys.types tp ON tp.user_type_id = c.user_type_id'
+IIF(@tableSearchPattern IS NOT NULL, CHAR(10)+'WHERE t.[name] LIKE '''+@tableSearchPattern+'''','')+
'

OPEN [tables]

FETCH NEXT FROM [tables] INTO @dbName, @schemaName, @tableName, @columnName, @columnType, @fullTableName

WHILE @@FETCH_STATUS = 0

BEGIN
	IF(@columnName IS NOT NULL AND @innerValuePattern IS NOT NULL)
	BEGIN
		SET @selectSql=N''SELECT [??] FROM ''+@fullTableName+N'' WHERE ''+(CASE WHEN @columnType COLLATE Latin1_General_CI_AS = N''image'' THEN N''CONVERT(NVARCHAR(MAX),CONVERT(VARBINARY(MAX),''+@columnName+N''),1)'' WHEN @columnType COLLATE Latin1_General_CI_AS = N''xml'' THEN N''CONVERT(nvarchar(MAX),''+@columnName+N'')'' WHEN @columnType COLLATE Latin1_General_CI_AS IN (N''hierarchyid'',N''geography'') THEN @columnName+N''.ToString()'' WHEN @columnType COLLATE Latin1_General_CI_AS IN (N''datetime'',N''datetime2'',N''datetimeoffset'',N''time'') THEN N''CONVERT(nvarchar(50),''+@columnName+N'',126)'' ELSE @columnName END)+N'' LIKE ''''''+@innerValuePattern+N'''''''' 
		SET @sql=N''IF EXISTS (''+REPLACE(@selectSql COLLATE Latin1_General_CI_AS,''[??]'',''1'')+N'')'' 
	END
	ELSE
	BEGIN
		SET @selectSql = NULL
		SET @sql=N''''
	END

	SET @sql = @sql+N'' INSERT INTO #Output SELECT ''''''+@dbName+N'''''',''''''+@schemaName+N'''''',''''''+@tableName+N'''''',''''''+COALESCE(@columnName,N'''')+N'''''',''''''+@fullTableName+N'''''',''''''+REPLACE(REPLACE(@selectSql COLLATE Latin1_General_CI_AS,''[??]'',''*''),'''''''','''''''''''')+N''''''''

	PRINT @sql

	EXECUTE sp_executesql @sql

	FETCH NEXT FROM [tables] INTO @dbName, @schemaName, @tableName, @columnName, @columnType, @fullTableName

END

CLOSE [tables]; 
DEALLOCATE [tables];

'

PRINT @statement

DECLARE [databases] CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR
SELECT [name]
FROM sys.databases

OPEN [databases]
FETCH NEXT FROM [databases] INTO @outerDbName

WHILE @@FETCH_STATUS = 0
BEGIN
	IF (@outerDbName NOT IN ('master','msdb','tempdb', 'model', 'ReportServer') AND (@dbSearchPattern IS NULL OR @outerDbName LIKE @dbSearchPattern))
	BEGIN
		DECLARE @statementForDatabase NVARCHAR(MAX) = REPLACE(@statement,N'[?]',@outerDbName)
		EXECUTE sp_executesql @statementForDatabase,N'@innerValuePattern nvarchar(1000)',@innerValuePattern = @valuePattern
	END
	FETCH NEXT FROM [databases] INTO @outerDbName
END

CLOSE [databases]; 
DEALLOCATE [databases];

SELECT * FROM #Output

END
