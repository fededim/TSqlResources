-- © 2020 Federico Di Marco <fededim@gmail.com> (initially implemented in 2008 with older version Microsoft Access Database Engine)

-- BEGIN of only once setup

-- Enable ad hoc queries on server
sp_configure 'show advanced options',1
reconfigure
GO
sp_configure 'Ad Hoc Distributed Queries',1
reconfigure

--Install Microsoft Access Database Engine 2016 Redistributable on server https://www.microsoft.com/en-us/download/details.aspx?id=54920

-- Launch on Sql Server
USE [master]
GO
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1
GO
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'DynamicParameters', 1 

-- restart Sql Server

-- END of only once setup



-- FOR either CSV or XLSX you have to copy the file on server, ensure that the user of Sql Server service has read access to both folder and file


-- FOR CSV (comma separated), set HDR parameter to YES only if header is present, 
SELECT * FROM OPENROWSET('Microsoft.ACE.OLEDB.16.0','Text;Database=<only directories to file.csv>;HDR=YES','SELECT * FROM <file.csv>')


-- FOR CSV (different separator than comma)
-- you have to create an additional file in the same folder named schema.ini to specify the separator, contents:
--[<file.csv>]
--ColNameHeader=True
--CharacterSet=ANSI
--Format=Delimited(<separator char>)
SELECT * FROM OPENROWSET('Microsoft.ACE.OLEDB.16.0','Text;Database=<only directories to file.csv>;HDR=YES','SELECT * FROM <file.csv>')


-- FOR XLSX
SELECT * FROM OPENROWSET('Microsoft.ACE.OLEDB.16.0','Excel 12.0; Database=<full path to file.csv>', [<sheet name>$])