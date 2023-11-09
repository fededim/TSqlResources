/*********************************************************************************************
© 2016	Federico Di Marco <fededim@gmail.com>
spReapplyLoginToDatabases - A helper stored procedure which recreates/restores the database user 
with db_datareader and db_datawriter roles and optionally the grant to execute the stored procedures for the specified login 
for all databases in a server.

PARAMETERS:
	- @loginname: a SQL LIKE pattern to specify the login (only the first match is taken)
	- @grantExecute: a BIT which specifies whether to grant the execute permission on stored procedure for the user
 
OUTPUT:
A log table with these columns:
  - [Database]: database name to which the LogMessage applies
  - [LogMessage]: the message logged during the execution

USAGE:
exec spReapplyLoginToDatabases 'test' -- recreates the user for the test login in all databases of the server with db_datareader and db_datawriter role
exec spReapplyLoginToDatabases 'test',1 -- recreates the user for the test login in all databases of the server with db_datareader and db_datawriter role and grants also the permission to execute the stored procedures

VERSION HISTORY:
  20161001	fededim		Initial Release
 
*********************************************************************************************/

CREATE OR ALTER PROCEDURE spReapplyLoginToDatabases (@loginname nvarchar(100), @grantExecute bit=0)
AS
BEGIN

CREATE TABLE #Log ([Database] nvarchar(200), LogMessage nvarchar(1000))

DECLARE @statement NVARCHAR(2000)=N'
USE [?]

IF DB_NAME() NOT IN(N''master'', N''msdb'', N''tempdb'', N''model'', N''ReportServer'')
BEGIN
	DECLARE @loginname nvarchar(100), @username nvarchar(100), @statement nvarchar(2000)

	SELECT TOP(1) @loginname=name FROM sys.server_principals WHERE [name] LIKE N'''+@loginName+'''

	IF (@loginname IS NOT NULL)
	BEGIN
		PRINT ''Database ''+DB_NAME()

		SELECT TOP (1) @username=u.[name] 
		FROM sys.sysusers u
		INNER JOIN sys.server_principals p ON u.sid=p.sid
		WHERE p.[name] LIKE @loginname

		SET @statement=''''

		IF @username IS NULL
		BEGIN
			SET @username=@loginname

			-- Create user for login
			SET @statement=@statement+''CREATE USER [''+@username+''] FOR LOGIN [''+@loginname+'']''+CHAR(10)
		END

		IF @username<>''dbo''
		BEGIN
			-- Add db_datareader, add db_datawriter roles, log action
			SET @statement=@statement+''ALTER ROLE [db_datareader] ADD MEMBER [''+@username+'']''+CHAR(10)+''ALTER ROLE [db_datawriter] ADD MEMBER [''+@username+'']''+CHAR(10)
			IF ('+convert(nvarchar(1),@grantExecute)+'=1)
				SET @statement=@statement+N''GRANT EXECUTE TO [''+@username+'']''+CHAR(10)

			SET @statement=@statement+N''INSERT INTO #Log SELECT DB_NAME(), ''''Restored user ''+@username+'' for login ''+@loginname+''''''''

		END
		ELSE
		BEGIN
			SET @statement=N''INSERT INTO #Log SELECT DB_NAME(), ''''Login ''+@loginname+N'' is already dbo, nothing done.''''''
		END

		PRINT @statement
		EXEC sp_executesql @statement
	END
END'

PRINT @statement

EXEC Sp_MsForEachDb @statement

SELECT * FROM #Log

END
