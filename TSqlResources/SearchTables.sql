CREATE OR ALTER PROCEDURE searchTables
(@dbSearchPattern nvarchar(256)=NULL, 
 @tableSearchPattern nvarchar(256),
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
 [Column] nvarchar(100),
 [FullTableName] nvarchar(400)
)

DECLARE @statement NVARCHAR(max) = N'
USE [?]

IF DB_NAME() NOT IN (''master'',''msdb'',''tempdb'', ''model'', ''ReportServer'')'+ IIF (@dbSearchPattern IS NOT NULL, ' AND (DB_NAME() LIKE '''+@dbSearchPattern+''')','')+'
BEGIN

	DECLARE @schemaName nvarchar(200),@tableName nvarchar(200), @columnName nvarchar(200), @fullTableName nvarchar(1000), @sql nvarchar(4000)

	PRINT ''Checking database ?''

	DECLARE [tables] CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR

	SELECT s.[name] AS SchemaName,t.[name] AS TableName,c.[name] AS ColumnName,''[''+s.[name]+''].[''+t.[name]+'']'' AS FullName
	FROM sys.tables t
	INNER JOIN sys.schemas s ON t.schema_id=s.schema_id'+
  CHAR(10)+CHAR(9)+IIF(@columnSearchPattern IS NOT NULL,'INNER','LEFT')+' JOIN sys.columns c ON c.[name] LIKE '''+COALESCE(@columnSearchPattern,'')+''' AND c.[object_id]=t.[object_id]'
  +IIF(@tableSearchPattern IS NOT NULL, CHAR(10)+CHAR(9)+'WHERE t.[name] LIKE '''+@tableSearchPattern+'''','')+
'

	OPEN [tables]

	FETCH NEXT FROM [tables] INTO @schemaName, @tableName, @columnName, @fullTableName

	WHILE @@FETCH_STATUS = 0

	BEGIN

'+
IIF(@columnSearchPattern IS NOT NULL AND @valuePattern IS NOT NULL,
    CHAR(9)+CHAR(9)+'SET @sql=''IF EXISTS (SELECT 1 FROM ''+@fullTableName+'' WHERE [''+ @columnName+''] LIKE '''''+@valuePattern+''''') ',
    CHAR(9)+CHAR(9)+'SET @sql=''')
+'INSERT INTO #Output SELECT DB_NAME(),''''''+@schemaName+'''''',''''''+@tableName+'''''',@innerColumnName,''''[''+DB_NAME()+''].''+@fullTableName+IIF(@columnName IS NOT NULL,''.[''+@columnName+'']'''''','''''''')

		PRINT @sql

		EXECUTE sp_executesql @sql, N''@innerColumnName nvarchar(100)'',@innerColumnName=@columnName

		FETCH NEXT FROM [tables] INTO @schemaName, @tableName, @columnName, @fullTableName

  END

  CLOSE [tables]; 
  DEALLOCATE [tables];

END

'

PRINT @statement

EXEC sp_MSforeachdb @statement

SELECT * FROM #Output

END
