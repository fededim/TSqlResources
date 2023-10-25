/*********************************************************************************************
© 2023	Federico Di Marco <fededim@gmail.com>
spSearchTables - A helper stored procedure which allows to search tables or columns either by name or by value in all databases in a server

PARAMETERS:
	- @dbSearchPattern: a SQL LIKE pattern to filter databases, set to NULL to search in all databases
	- @tableSearchPattern: a SQL LIKE pattern to filter tables, set to  NULL to search in all tables
	- @columnSearchPattern: a SQL LIKE pattern to filter columns, set to NULL to peform search only on tables, set to '%' to search also on all columns
	- @valuePattern: a SQL LIKE pattern to filter column value, set to NULL to not to search on column values
 
OUTPUT:
A table with these columns:
  - [Database]: database names matching @dbSearchPattern parameter
  - [Schema]: schema names matching @tableSearchPattern parameter
  - [Table]: table names  matching @columnSearchPattern parameter
  - [FullTableName]: it's just the concatenation of database + schema + table
  - [MatchingColumns]: comma separated list of column names matching the @columnsSearchPattern
  - [MatchingSelect]: the select statement returning the columns and rows matching the @valuePattern (it supports all column datatypes)

SAMPLE SEARCHES:
exec spSearchTables NULL,NULL,NULL,NULL - returns all tables with all columns in all databases in the server
exec spSearchTables 'North%',NULL,NULL,NULL - returns all tables with all columns in all databases starting with North% in the server
exec spSearchTables 'North%','S%',NULL,NULL - returns tables starting with S% with all columns in databases starting with North% in the server
exec spSearchTables 'North%','S%','P%',NULL - returns tables starting with S% with columns starting with P% in databases starting with North% in the server 
exec spSearchTables 'North%','S%','P%','30%' - returns tables starting with S% with columns starting with P% whose value matches 30% in databases starting with North% in the server
exec spSearchTables NULL,NULL,NULL,'30%' - returns all table and all columns whose value matches 30% in all databases in the server

VERSION HISTORY:
  20231021	fededim		Initial Release
  20231025	fededim		improved check for values now it uses just a single query for each table / flattened matching columns in a comma separated list / added MatchingColumns as first ones in the MatchingSelect query
  20231025	fededim		improved handling of @columnSearchPattern parameter, now you can use it without specifying @valuePattern parameter
 
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
 [FullTableName] nvarchar(300),
 [MatchingColumns] nvarchar(max),
 [MatchingSelect] nvarchar(max),
)

DECLARE @outerDbName nvarchar(100)

DECLARE @statement NVARCHAR(max) = CAST('' as NVARCHAR(MAX))+N'
USE [?]


DECLARE @dbName nvarchar(200), @schemaName nvarchar(200),@tableName nvarchar(200), @columnName nvarchar(200), @columnType nvarchar(200), @fullTableName nvarchar(1000)  -- current data
DECLARE @oldDbName nvarchar(200), @oldSchemaName nvarchar(200),@oldTableName nvarchar(200), @oldFullTableName nvarchar(1000)  -- old data
DECLARE @whereColumnName nvarchar(200), @whereCondition nvarchar(400), @whereClause nvarchar(max), @sql nvarchar(max), @selectSql nvarchar(max), @columnListSelect nvarchar(max)  -- helper variables

PRINT N''Checking database [?]''

DECLARE [tables] CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR
SELECT N''[''+ DB_NAME() +N'']'' AS DatabaseName,N''[''+ s.[name] +N'']'' AS SchemaName,N''[''+ t.[name] +N'']'' AS TableName,N''[''+ c.[name] +N'']'' AS ColumnName,tp.[Name] AS ColumnType, N''[''+DB_NAME()+N''].[''+s.[name]+N''].[''+t.[name]+N'']'' AS FullTableName
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id=s.schema_id
INNER JOIN sys.columns c ON (@innerColumnSearchPattern IS NULL OR c.[name] LIKE @innerColumnSearchPattern) AND c.[object_id]=t.[object_id]
INNER JOIN sys.types tp ON tp.user_type_id = c.user_type_id'
+IIF(@tableSearchPattern IS NOT NULL, CHAR(10)+'WHERE t.[name] LIKE '''+@tableSearchPattern+'''','')
+CHAR(10)+N'ORDER BY FullTableName

SET @oldFullTableName = NULL

OPEN [tables]

FETCH NEXT FROM [tables] INTO @dbName, @schemaName, @tableName, @columnName, @columnType, @fullTableName
WHILE (1=1)
BEGIN
	IF ((@oldFullTableName<>@fullTableName AND @oldFullTableName IS NOT NULL) OR @@FETCH_STATUS<>0)
	BEGIN
		IF (@whereClause IS NOT NULL)
		BEGIN
			SET @whereClause = REPLACE(CONCAT(@whereClause,N''[???]'') COLLATE Latin1_General_CI_AS,N''OR [???]'',N'''')  --trim last "OR "
			SET @selectSql = N''SELECT [??] FROM ''+@oldFullTableName+N'' WHERE '' + @whereClause 
		END
		ELSE
			SET @selectSql = NULL

		IF (@columnListSelect IS NOT NULL)
		BEGIN
			SET @columnListSelect = N''REPLACE(CONCAT(''+@columnListSelect + N''''''[???]'''') COLLATE Latin1_General_CI_AS,N'''',[???]'''',N'''''''')''  -- trim last ","
			SET @sql = N'' INSERT INTO #Output SELECT  ''''''+@oldDbName+N'''''',''''''+@oldSchemaName+N'''''',''''''+@oldTableName+N'''''',''''''+@oldFullTableName+N'''''',''+@columnListSelect+N'',''''''+REPLACE(@selectSql COLLATE Latin1_General_CI_AS,'''''''','''''''''''')+N''''''''+IIF(@whereClause IS NOT NULL,'' FROM ''+@oldFullTableName+'' WHERE ''+@whereClause,'''')
		END
		ELSE IF (@oldDbName IS NOT NULL)
			SET @sql = N'' INSERT INTO #Output SELECT  ''''''+@oldDbName+N'''''',''''''+@oldSchemaName+N'''''',''''''+@oldTableName+N'''''',''''''+@oldFullTableName+N'''''',NULL,NULL''

		IF (@selectSql IS NOT NULL)
			SET @sql = N''IF EXISTS (''+REPLACE(@selectSql COLLATE Latin1_General_CI_AS,''[??]'',''1'')+N'')'' +@sql

		IF (@sql IS NOT NULL)
		BEGIN
			PRINT @sql

			EXECUTE sp_executesql @sql
		END

		IF (@@FETCH_STATUS<>0)
			BREAK

		SET @whereClause = NULL
		SET @columnListSelect = NULL
	END

	IF (@innerValuePattern IS NOT NULL)
	BEGIN
		SET @whereColumnName = (CASE WHEN @columnType COLLATE Latin1_General_CI_AS = N''image'' THEN N''CONVERT(NVARCHAR(MAX),CONVERT(VARBINARY(MAX),''+@columnName+N''),1)'' WHEN @columnType COLLATE Latin1_General_CI_AS = N''xml'' THEN N''CONVERT(nvarchar(MAX),''+@columnName+N'')'' WHEN @columnType COLLATE Latin1_General_CI_AS IN (N''hierarchyid'',N''geography'') THEN @columnName+N''.ToString()'' WHEN @columnType COLLATE Latin1_General_CI_AS IN (N''datetime'',N''datetime2'',N''datetimeoffset'',N''time'') THEN N''CONVERT(nvarchar(50),''+@columnName+N'',126)'' ELSE @columnName END)
		SET @whereCondition = N''('' + @whereColumnName+N'' LIKE ''''''+@innerValuePattern+N'''''')''

		SET @whereClause = @whereClause + @whereCondition + N'' OR ''

		SET @columnListSelect= @columnListSelect + N''IIF(SUM(CASE WHEN ''+@whereCondition+'' THEN 1 ELSE 0 END)>0,''''''+@columnName+'','''',NULL),''
	END
	ELSE
	BEGIN
		SET @whereClause = NULL
		SET @columnListSelect= @columnListSelect + N''MAX('''''' + @columnName + N'',''''),''
	END

	SET @oldDbName = @dbName
	SET @oldSchemaName = @schemaName
	SET @oldTableName = @tableName
	SET @oldFullTableName = @fullTableName

	FETCH NEXT FROM [tables] INTO @dbName, @schemaName, @tableName, @columnName, @columnType, @fullTableName
END	

CLOSE [tables]; 
DEALLOCATE [tables];

'


DECLARE @offsetToPrint bigint = 0

WHILE (@offsetToPrint<len(@statement))
BEGIN
	PRINT substring(@statement,@offsetToPrint, CASE WHEN len(@statement)-@offsetToPrint < 4000 THEN len(@statement)-@offsetToPrint ELSE 4000 END) -- it gets truncated to 4000 characters
	SET @offsetToPrint = @offsetToPrint + 4000
END


--SELECT CAST('<root><![CDATA[' + @statement + ']]></root>' AS XML) -- use this to show complete statement for debugging


DECLARE [databases] CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR
SELECT [name]
FROM sys.databases

OPEN [databases]
FETCH NEXT FROM [databases] INTO @outerDbName

WHILE @@FETCH_STATUS = 0
BEGIN
	IF (@outerDbName NOT IN ('master','msdb','tempdb', 'model', 'ReportServer') AND (@dbSearchPattern IS NULL OR @outerDbName LIKE @dbSearchPattern))
	BEGIN
		DECLARE @statementForDatabase NVARCHAR(MAX) = REPLACE(@statement,N'[?]','['+@outerDbName+']')
		EXECUTE sp_executesql @statementForDatabase,N'@innerValuePattern nvarchar(1000), @innerColumnSearchPattern nvarchar(256)',@innerValuePattern = @valuePattern, @innerColumnSearchPattern = @columnSearchPattern
	END
	FETCH NEXT FROM [databases] INTO @outerDbName
END

CLOSE [databases]; 
DEALLOCATE [databases];

UPDATE #Output
SET [MatchingSelect]=REPLACE([MatchingSelect],'[??]',[MatchingColumns]+',*')

SELECT * FROM #Output

END