/*********************************************************************************************
© 2008	Federico Di Marco <fededim@gmail.com>
BackupDatabase - A helper script which will perform a full backup of a database to a network location mounted on letter Z:
				 The script does not use any extra features like compression in order to as compatible as possible with every edition of Sql Server
				 Used only for databases in SIMPLE recovery mode.
PARAMETERS:
	- None
 
OUTPUT:
	- backup file

USAGE:
SELECT * FROM fnGetCalendarTable('2020-08-12T08:01:33.123456','2020-08-13T09:15:22',10) OPTION (MAXRECURSION 0)

VERSION HISTORY:
  20081001	fededim		Initial Release
 
*********************************************************************************************/
DECLARE @path VARCHAR(500)
DECLARE @name VARCHAR(500)
DECLARE @time DATETIME
DECLARE @year VARCHAR(4)
DECLARE @month VARCHAR(2)
DECLARE @day VARCHAR(2)
DECLARE @hour VARCHAR(2)
DECLARE @minute VARCHAR(2)
DECLARE @second VARCHAR(2)

-- 2. Map network drive
EXEC XP_CMDSHELL 'net use Z: \\<network share> /user:<domain\user> <password>'

-- 3. Getting the time values

SELECT @time   = GETDATE()
SELECT @year   = (SELECT CONVERT(VARCHAR(4), DATEPART(yyyy, @time)))
SELECT @month  = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(mm,@time),'00')))
SELECT @day    = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(dd,@time),'00')))
SELECT @hour   = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(hh,@time),'00')))
SELECT @minute = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(mi,@time),'00')))
SELECT @second = (SELECT CONVERT(VARCHAR(2), FORMAT(DATEPART(ss,@time),'00')))

-- 4. Defining the folder and filename format

SELECT @path='z:\Backups\'+@year+@month
SELECT @name =@path+'\<database_name>' + @year + @month + @day +'_' + @hour + @minute + @second+'.bak'

Declare @vFileExists int
 
exec XP_FILEEXIST @path, @vFileExists OUTPUT
 
IF (@vFileExists=0)
EXEC XP_CREATE_SUBDIR @path


--5. Executing the backup command

BACKUP DATABASE [<database_name>]
TO  DISK = @name WITH NOFORMAT, INIT,  NAME = N'<database_name>-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10, CHECKSUM

--6 Unmap network drive
EXEC XP_CMDSHELL 'net use Z: /delete'
