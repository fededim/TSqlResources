/*********************************************************************************************
© 2023	Federico Di Marco <fededim@gmail.com>
spSearchTables - A helper stored procedure which allows to search tables or columns either by name or by value in all databases in a server

PARAMETERS:
	- @dbSearchPattern: a SQL LIKE pattern to filter databases, set to NULL to search in all databases
	- @schemaSearchPattern: a SQL LIKE pattern to filter schemas, set to NULL to search in all schemas
	- @tableSearchPattern: a SQL LIKE pattern to filter tables, set to  NULL to search in all tables
	- @columnTypeSearchPattern: a SQL LIKE pattern to filter column type, set to NULL to search in all column types
	- @columnSearchPattern: a SQL LIKE pattern to filter columns, set to NULL to search in all columns
	- @valuePattern: a SQL LIKE pattern to filter column value, set to NULL to not to search on column values
 
OUTPUT:
A table with these columns:
  - [Database]: database names matching @dbSearchPattern parameter
  - [Schema]: schema names matching @tableSearchPattern parameter
  - [Table]: table names  matching @columnSearchPattern parameter
  - [FullTableName]: it's just the concatenation of database + schema + table
  - [MatchingColumns]: comma separated list of column names matching the @columnsSearchPattern
  - [MatchingSelect]: the select statement returning the columns and rows matching the @valuePattern (it supports all column datatypes)

USAGE:
exec spSearchTables NULL,NULL,NULL,NULL,NULL,NULL -- returns all tables with all columns in all databases in the server
exec spSearchTables 'North%','d%',NULL,NULL,NULL,NULL -- returns all tables with all columns in all databases starting with North% and having d% in the schema in the server
exec spSearchTables 'North%',NULL,'S%',NULL,NULL,NULL -- returns tables starting with S% with all columns in databases starting with North% in the server
exec spSearchTables 'North%',NULL,'S%','%int%',NULL,NULL -- returns tables starting with S% with all columns in databases starting with North% in the server and type %int%
exec spSearchTables 'North%',NULL,'S%',NULL,'P%',NULL -- returns tables starting with S% with columns starting with P% in databases starting with North% in the server 
exec spSearchTables 'North%',NULL,'S%',NULL,'P%','30%' -- returns tables starting with S% with columns starting with P% whose value matches 30% in databases starting with North% in the server
exec spSearchTables NULL,NULL,NULL,NULL,NULL,'30%' -- returns all table and all columns whose value matches 30% in all databases in the server
exec spSearchTables NULL,NULL,NULL,'geo%',NULL,'POINT (-122.274625789912 47.7631154083121)' -- WKT query: returns all table and all columns whose columntype is spatial (e.g. geometry or geography) and contain the specified WKT entity

VERSION HISTORY:
  20231021	fededim		Initial Release
  20231025	fededim		improved check for values now it uses just a single query for each table / flattened matching columns in a comma separated list / added MatchingColumns as first ones in the MatchingSelect query
  20231025	fededim		improved handling of @columnSearchPattern parameter, now you can use it without specifying @valuePattern parameter
  20231031	fededim		BREAKING CHANGE:
							- added schemaSearchPattern and columnTypeSearchPattern parameters
							- bugfix and improvement on geometry and geography column types
							- improvement on MatchingSelect output column: now it returns the converted columns used to perform where conditions
							- WKT can be used in @valuePattern to perform STContains query on spatial columns where supported (e.g. database compatibility level >=130)
  29112023	fededim		bugfix on MatchingSelect query, collate statement was not passed for converted columns 
						performance improvement: instead of performing twice the same query to populate columnListSelect and columnList
												 the code now returns an xml result (columnListXml) with both columns using just one single query
*********************************************************************************************/

CREATE OR ALTER PROCEDURE spSearchTables
(@dbSearchPattern nvarchar(256)=NULL, 
 @schemaSearchPattern nvarchar(256),
 @tableSearchPattern nvarchar(256),
 @columnTypeSearchPattern nvarchar(256)=NULL,
 @columnSearchPattern nvarchar(256)=NULL,
 @valuePattern nvarchar(1000)=NULL)
AS
BEGIN

-- Create output temporary table
CREATE TABLE #Output
(
 [Database] nvarchar(100),
 [Schema] nvarchar(100),
 [Table] nvarchar(100),
 [FullTableName] nvarchar(300),
 [MatchingColumns] nvarchar(max),
 [MatchingWhereColumns] nvarchar(max),
 [MatchingSelect] nvarchar(max),
)

DECLARE @outerDbName nvarchar(100)

DECLARE @statement NVARCHAR(max) = CAST('' as NVARCHAR(MAX))+N'
USE [?]


DECLARE @dbName nvarchar(200), @schemaName nvarchar(200),@tableName nvarchar(200), @columnName nvarchar(200), @columnType nvarchar(200), @fullTableName nvarchar(1000)  -- current data
DECLARE @oldDbName nvarchar(200), @oldSchemaName nvarchar(200),@oldTableName nvarchar(200), @oldFullTableName nvarchar(1000)  -- old data
DECLARE @whereColumnName nvarchar(200), @whereCondition nvarchar(400), @whereClause nvarchar(max), @sql nvarchar(max), @selectSql nvarchar(max), @columnListXml nvarchar(max)   -- helper variables

-- try to parse innerValuePattern with geometry and geography types
DECLARE @geometry geometry, @geography geography, @compatibilityLevel int

BEGIN TRY
	SELECT @compatibilityLevel = compatibility_level FROM sys.databases WHERE database_id=DB_ID()
	SELECT @geography=geography::Parse(@innerValuePattern)
	SELECT @geometry=geometry::Parse(@innerValuePattern)
END TRY
BEGIN CATCH
END CATCH



PRINT N''Checking database [?]''

DECLARE [tables] CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR
SELECT N''[''+ DB_NAME() +N'']'' AS DatabaseName,N''[''+ s.[name] +N'']'' AS SchemaName,N''[''+ t.[name] +N'']'' AS TableName,N''[''+ c.[name] +N'']'' AS ColumnName,tp.[Name] AS ColumnType, N''[''+DB_NAME()+N''].[''+s.[name]+N''].[''+t.[name]+N'']'' AS FullTableName
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id=s.schema_id AND (@innerSchemaSearchPattern IS NULL OR s.[name] LIKE @innerSchemaSearchPattern)
INNER JOIN sys.columns c ON (@innerColumnSearchPattern IS NULL OR c.[name] LIKE @innerColumnSearchPattern) AND c.[object_id]=t.[object_id]
INNER JOIN sys.types tp ON tp.user_type_id = c.user_type_id AND (@innerColumnTypeSearchPattern IS NULL OR tp.[name] LIKE @innerColumnTypeSearchPattern)'
+IIF(@tableSearchPattern IS NOT NULL, CHAR(10)+'WHERE t.[name] LIKE '''+@tableSearchPattern+'''','')
+CHAR(10)+N'ORDER BY FullTableName

SET @oldFullTableName = NULL
SET @columnListXml = N''''

OPEN [tables]

FETCH NEXT FROM [tables] INTO @dbName, @schemaName, @tableName, @columnName, @columnType, @fullTableName
WHILE (1=1)
BEGIN
	IF ((@oldFullTableName<>@fullTableName AND @oldFullTableName IS NOT NULL) OR @@FETCH_STATUS<>0)
	BEGIN
		IF (@whereClause IS NOT NULL)
		BEGIN
			SET @whereClause = REPLACE(CONCAT(@whereClause,N''[???]'') COLLATE DATABASE_DEFAULT,N''OR [???]'',N'''')  --trim last "OR "
			SET @selectSql = N''SELECT [??] FROM ''+@oldFullTableName+N'' WHERE '' + @whereClause 
		END
		ELSE
			SET @selectSql = NULL

		SET @columnListXml = CONCAT(N''CONCAT(N''''<root>'''','',@columnListXml,N''''''</root>'''')'')

		--PRINT @columnListXml

		IF (@columnListXml LIKE N''%<columnListSelect>%</columnListSelect>%'' COLLATE DATABASE_DEFAULT)
		BEGIN
			SET @sql = N'' INSERT INTO #Output SELECT [Database],[Schema],[Table],[FullTableName],(SELECT REPLACE(CONCAT((SELECT CAST(x.col.value(''''.'''',''''nvarchar(max)'''')+N'''','''' AS NVARCHAR(MAX)) FROM [ColumnListXml].nodes(''''/root/column/columnList'''') AS x(col) FOR XML PATH('''''''')),''''[???]''''),'''',[???]'''','''''''')) AS [MatchingColumns],(SELECT REPLACE(CONCAT((SELECT CAST(x.col.value(''''.'''',''''nvarchar(max)'''')+N'''','''' AS NVARCHAR(MAX)) FROM [ColumnListXml].nodes(''''/root/column/columnListSelect'''') AS x(col) FOR XML PATH('''''''')),''''[???]''''),'''',[???]'''','''''''')) AS [MatchingWhereColumns],[MatchingSelect] FROM (SELECT  ''''''+@oldDbName+N'''''' AS [Database],''''''+@oldSchemaName+N'''''' AS [Schema],''''''+@oldTableName+N''''''  AS [Table],''''''+@oldFullTableName+N'''''' AS [FullTableName],CAST(''+@columnListXml+N'' AS xml) AS [ColumnListXml],''''''+REPLACE(@selectSql COLLATE DATABASE_DEFAULT,'''''''','''''''''''')+N'''''' AS [MatchingSelect]''+IIF(@whereClause IS NOT NULL,N'' FROM ''+@oldFullTableName+N'' WHERE ''+@whereClause,N'''')+N'') AS Nested''
		END
		ELSE IF (@oldDbName IS NOT NULL)
		BEGIN
			SET @sql = N'' INSERT INTO #Output SELECT [Database],[Schema],[Table],[FullTableName],(SELECT REPLACE(CONCAT((SELECT CAST(x.col.value(''''.'''',''''nvarchar(max)'''')+N'''','''' AS NVARCHAR(MAX)) FROM [ColumnListXml].nodes(''''/root/column/columnList'''') AS x(col) FOR XML PATH('''''''')),''''[???]''''),'''',[???]'''','''''''')) AS [MatchingColumns],NULL AS [MatchingWhereColumns],[MatchingSelect] FROM (SELECT  ''''''+@oldDbName+N'''''' AS [Database],''''''+@oldSchemaName+N'''''' AS [Schema],''''''+@oldTableName+N'''''' AS [Table],''''''+@oldFullTableName+N'''''' AS [FullTableName],CAST(''+@columnListXml+N'' AS xml) AS [ColumnListXml],NULL AS [MatchingSelect]) AS Nested''
		END

		IF (@selectSql IS NOT NULL)
			SET @sql = N''IF EXISTS (''+REPLACE(@selectSql COLLATE DATABASE_DEFAULT,''[??]'',''1'')+N'')'' +@sql

		IF (@sql IS NOT NULL)
		BEGIN
			PRINT @sql

			EXECUTE sp_executesql @sql
		END

		IF (@@FETCH_STATUS<>0)
			BREAK

		SET @whereClause = NULL
		SET @columnListXml = N''''
	END

	IF (@innerValuePattern IS NOT NULL)
	BEGIN
		SET @whereColumnName = (CASE WHEN @columnType COLLATE DATABASE_DEFAULT = N''image'' THEN N''CONVERT(NVARCHAR(MAX),CONVERT(VARBINARY(MAX),''+@columnName+N''),1)'' WHEN @columnType COLLATE DATABASE_DEFAULT = N''xml'' THEN N''CONVERT(nvarchar(MAX),''+@columnName+N'')'' WHEN @columnType COLLATE DATABASE_DEFAULT IN (N''hierarchyid'') THEN @columnName+N''.ToString()'' WHEN @columnType COLLATE DATABASE_DEFAULT IN (N''datetime'',N''datetime2'',N''datetimeoffset'',N''time'') THEN N''CONVERT(nvarchar(50),''+@columnName+N'',126)'' ELSE @columnName END)
		
		IF (@columnType COLLATE DATABASE_DEFAULT IN (N''geography'',N''geometry''))
		BEGIN	
			IF (@compatibilityLevel>=130 AND ((@columnType COLLATE DATABASE_DEFAULT = N''geometry'' AND @geometry IS NOT NULL)
				OR (@columnType COLLATE DATABASE_DEFAULT = N''geography'' AND @geography IS NOT NULL)))
				SET @whereCondition = N''COALESCE(''+@whereColumnName+N''.STContains(''+IIF(@columnType COLLATE DATABASE_DEFAULT = N''geometry'',N''geometry::Parse(''''''+@geometry.ToString()+N'''''')),0)=1)'',N''geography::Parse(''''''+@geography.ToString()+N'''''')),0)=1'')
			ELSE
				SET @whereCondition = N''('' + @whereColumnName+N''.ToString() LIKE N''''''+@innerValuePattern+N'''''' COLLATE DATABASE_DEFAULT)''

			SET @whereColumnName = @whereColumnName+N''.ToString()''
		END
		ELSE
			SET @whereCondition = N''('' + @whereColumnName+N'' LIKE ''''''+@innerValuePattern+N''''''''+IIF(@whereColumnName<>@columnName,N'' COLLATE DATABASE_DEFAULT'',N'''')+'')''

		SET @whereClause = COALESCE(@whereClause,N'''') + @whereCondition + N'' OR ''

		SET @columnListXml = @columnListXml + N''IIF(SUM(CASE WHEN ''+@whereCondition+N'' THEN 1 ELSE 0 END)>0,N''''<column><columnListSelect><![CDATA[''+@whereColumnName+'' AS ''+@columnName+'']]></columnListSelect><columnList><![CDATA[''+@columnName+'']]></columnList></column>'''',N''''''''),''
	END
	ELSE
	BEGIN
		SET @whereClause = NULL
		SET @columnListXml = @columnListXml + ''N''''<column><columnList><![CDATA[''+@columnName+'']]></columnList></column>'''',''
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
		EXECUTE sp_executesql @statementForDatabase,N'@innerValuePattern nvarchar(1000), @innerColumnSearchPattern nvarchar(256), @innerSchemaSearchPattern nvarchar(256), @innerColumnTypeSearchPattern nvarchar(256)',@innerValuePattern = @valuePattern, @innerColumnSearchPattern = @columnSearchPattern, @innerSchemaSearchPattern = @schemaSearchPattern, @innerColumnTypeSearchPattern = @columnTypeSearchPattern
	END
	FETCH NEXT FROM [databases] INTO @outerDbName
END

CLOSE [databases]; 
DEALLOCATE [databases];

UPDATE #Output
SET [MatchingSelect]=REPLACE([MatchingSelect],'[??]',[MatchingWhereColumns]+',*')

SELECT [Database],[Schema],[Table],[FullTableName],[MatchingColumns],[MatchingSelect]
FROM #Output
ORDER BY [FullTableName]

END