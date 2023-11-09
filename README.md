# TSqlResources
A set of resources for Sql Server


# Stored Procedures (SPs folder)

## [spReapplyLoginToDatabases.sql](https://github.com/fededim/TSqlResources/blob/master/TSqlResources/SPs/spReapplyLoginToDatabases.sql)

### Parameters
	- @loginname: a SQL LIKE pattern to specify the login (only the first match is taken)
	- @grantExecute: a BIT which specifies whether to grant the execute permission on stored procedure for the user

### OUTPUT
A log table with these columns:
	- [Database]: database name to which the LogMessage applies
	- [LogMessage]: the message logged during the execution

### USAGE
	- exec spReapplyLoginToDatabases 'test' -- recreates the user for the test login in all databases of the server with db_datareader and db_datawriter role
	- exec spReapplyLoginToDatabases 'test',1 -- recreates the user for the test login in all databases of the server with db_datareader and db_datawriter role and grants also the permission to execute the stored procedures

## [spSearchTables.sql](https://github.com/fededim/TSqlResources/blob/master/TSqlResources/SPs/spSearchTables.sql)

A helper stored procedure which allows to search tables or columns either by name or by value in all databases in a server. [Link to CodeProject article.](https://www.codeproject.com/Articles/5370606/spSearchTables-a-helper-T-SQL-stored-procedure-for)

### Parameters

exec spSearchTables @dbSearchPattern, @tableSearchPattern, @columnSearchPattern, @valuePattern

	- @dbSearchPattern: a SQL LIKE pattern to filter databases, set to NULL to search in all databases
	- @schemaSearchPattern: a SQL LIKE pattern to filter schemas, set to NULL to search in all schemas
	- @tableSearchPattern: a SQL LIKE pattern to filter tables, set to  NULL to search in all tables
	- @columnTypeSearchPattern: a SQL LIKE pattern to filter column type, set to NULL to search in all column types	
	- @columnSearchPattern: a SQL LIKE pattern to filter columns, set to NULL to search in all columns
	- @valuePattern: a SQL LIKE pattern to filter column value, set to NULL to not to search on column values
 
### OUTPUT

A table with these columns:

	- [Database]: database names matching @dbSearchPattern parameter
	- [Schema]: schema names matching @tableSearchPattern parameter
	- [Table]: table names  matching @columnSearchPattern parameter
	- [FullTableName]: it's just the concatenation of database + schema + table
	- [MatchingColumns]: comma separated list of column names matching the @columnsSearchPattern
	- [MatchingSelect]: the select statement returning the columns and rows matching the @valuePattern (it supports all column datatypes)

### USAGE

	- exec spSearchTables NULL,NULL,NULL,NULL,NULL,NULL - returns all tables with all columns in all databases in the server
	- exec spSearchTables 'North%','d%',NULL,NULL,NULL,NULL - returns all tables with all columns in all databases starting with North% and having d% in the schema in the server
	- exec spSearchTables 'North%',NULL,'S%',NULL,NULL,NULL - returns tables starting with S% with all columns in databases starting with North% in the server
	- exec spSearchTables 'North%',NULL,'S%','%int%',NULL,NULL - returns tables starting with S% with all columns in databases starting with North% in the server and type %int%
	- exec spSearchTables 'North%',NULL,'S%',NULL,'P%',NULL - returns tables starting with S% with columns starting with P% in databases starting with North% in the server 
	- exec spSearchTables 'North%',,NULL,'S%',NULL,'P%','30%' - returns tables starting with S% with columns starting with P% whose value matches 30% in databases starting with North% in the server
	- exec spSearchTables NULL,NULL,NULL,NULL,NULL,'30%' - returns all table and all columns whose value matches 30% in all databases in the server
	- exec spSearchTables NULL,NULL,NULL,'geo%',NULL,'POINT(-122.35900 47.65129)' - WKT query: returns all table and all columns whose columntype is spatial (e.g. geometry or geography) and contain the specified WKT entity

# Functions (Functions folder)

## [fnGetCalendarTable.sql](https://github.com/fededim/TSqlResources/blob/master/TSqlResources/Functions/fnGetCalendarTable.sql)

A helper table valued function which returns a range of dates from a startDate to an endDate using the stepMin step in minutes

### PARAMETERS
	- @startDate: the date from which the calendar table should start
	- @endDate: the date to which the calendar table should stop
	- @stepMin: the increment step in minutes
 
### OUTPUT
	- A calendar table

### USAGE
	- SELECT * FROM fnGetCalendarTable('2020-08-12T08:01:33.123456','2020-08-13T09:15:22',10) OPTION (MAXRECURSION 0)


# Scripts (Scripts folder)

## [DbMaintenance.sql](https://github.com/fededim/TSqlResources/blob/master/TSqlResources/Scripts/dbMaintenance.sql)
A helper script which must be scheduled every day (or more frequently) to rebuild all fragmented indexes of a database and update all its statistics

## [QueryExcelCsv.sql](https://github.com/fededim/TSqlResources/blob/master/TSqlResources/Scripts/QueryExcelCsv.sql)
An example script which can be used to query CSV or XSLX files directly in Sql Management Studio without importing them into tables. [Link to CodeProject article.](https://www.codeproject.com/Tips/5370433/Query-Excel-or-CSV-files-with-T-SQL)

## [BackupDatabase.Sql](https://github.com/fededim/TSqlResources/blob/master/TSqlResources/Scripts/BackupDatabase.sql)
A helper script which will perform a backup of a database to a network location mounted on letter Z:
