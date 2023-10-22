/*********************************************************************************************
© 2020	Federico Di Marco <fededim@gmail.com> (initially implemented in 2008 with older version Microsoft Access Database Engine)
QueryExcelCsv - An example script which can be used to query CSV or XSLX files directly in Sql Management Studio without importing them into tables

PARAMETERS:
	- None
 
OUTPUT:
	- None

VERSION HISTORY:
  20161001	fededim		Initial Release
 
*********************************************************************************************/

-- SETUP: do only ONCE per server

-- Enable ad hoc queries on server
sp_configure 'show advanced options',1
reconfigure
GO
sp_configure 'Ad Hoc Distributed Queries',1
reconfigure
GO
	
--Install Microsoft Access Database Engine 2016 Redistributable on server https://www.microsoft.com/en-us/download/details.aspx?id=54920

-- Enable InProcess and DynamicParameters
USE [master]
GO
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1
GO
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'DynamicParameters', 1 
GO
	
-- Restart Sql Server

-- SETUP: END of only once setup



-- FOR either CSV or Excel you have to copy the file on server, ensure that the user of Sql Server service has read access to both folder and file


-- FOR CSV (comma separated), you can set the HDR parameter to YES if first row of CSV file contains the column names.
SELECT * FROM OPENROWSET('Microsoft.ACE.OLEDB.16.0','Text;Database=<path to file.csv>;HDR=YES','SELECT * FROM <file.csv>')


-- FOR CSV (different separator than comma)
-- you have to create an additional file in the same folder named schema.ini to specify the separator, contents:
--[<file.csv>]
--ColNameHeader=True
--CharacterSet=ANSI
--Format=Delimited(<separator char>)
SELECT * FROM OPENROWSET('Microsoft.ACE.OLEDB.16.0','Text;Database=<only directories to file.csv>;HDR=YES','SELECT * FROM <file.csv>')


-- FOR XLSX or XLS
SELECT * FROM OPENROWSET('Microsoft.ACE.OLEDB.16.0','Excel 12.0; Database=<full path to excel.xlsx>', [<sheet name>$])
