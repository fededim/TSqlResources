/*********************************************************************************************
© 2016	Federico Di Marco <fededim@gmail.com>
DbMaintenance - A helper script which must be scheduled every day (or more frequently) to rebuild all fragmented indexes of a database and update all its statistics

PARAMETERS:
	- None
 
OUTPUT:
	- None

VERSION HISTORY:
  20161001	fededim		Initial Release
 
*********************************************************************************************/

DECLARE @statement NVARCHAR(4000) -- statement 

PRINT 'Script started at '+CONVERT(NVARCHAR(256),GetDate(),113)

PRINT CHAR(13)+'Updating indexes...'

DECLARE db_cursor CURSOR FOR 
SELECT 
		--S.[Name] as 'Schema',T.[Name] as 'Table',I.[Name] as 'Index',
		--DDIPS.avg_fragmentation_in_percent,
		--DDIPS.page_count,
		CASE 
			WHEN DDIPS.avg_fragmentation_in_percent BETWEEN 15 AND 30 THEN 'ALTER INDEX ['+I.[Name]+'] ON ['+S.[Name]+'].['+T.[Name]+'] REORGANIZE'
			ELSE 'ALTER INDEX ['+I.[Name]+'] ON ['+S.[Name]+'].['+T.[Name]+'] REBUILD'
		END AS Statement
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS DDIPS
INNER JOIN sys.tables T on T.object_id = DDIPS.object_id
INNER JOIN sys.schemas S on T.schema_id = S.schema_id
INNER JOIN sys.indexes I ON I.object_id = DDIPS.object_id AND DDIPS.index_id = I.index_id
WHERE DDIPS.database_id = DB_ID() and I.[Name] is not null
	  AND (DDIPS.avg_fragmentation_in_percent > 15)
ORDER BY S.[Name],T.[Name],case when I.[Name] like 'PK_%' then 1 else 2 end,DDIPS.avg_fragmentation_in_percent desc

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @statement  

WHILE @@FETCH_STATUS = 0  
BEGIN  
	  PRINT 'Executing '+@statement
	  EXEC sp_executesql @stmt=@statement

      FETCH NEXT FROM db_cursor INTO @statement 
END 

CLOSE db_cursor  
DEALLOCATE db_cursor

PRINT CHAR(13)+'Updating statistics...'
exec sp_updatestats

PRINT CHAR(13)+'Script ended at '+CONVERT(NVARCHAR(256),GetDate(),113)+CHAR(13)+CHAR(13)
