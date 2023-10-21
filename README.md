# TSqlResources
A set of resources for Sql Server


# Stored Procedures (SPs folder)

## spSearchTables.sql

A helper stored procedure which allows to search tables or columns either by name or by value in all databases in a server

# Functions (Functions folder)

## fnGetCalendarTable.sql

A helper table valued function which returns a range of dates from a startDate to an endDate using the stepMin step in minutes

# Scripts (Scripts folder)

## Script_db_maintenance.sql
A helper script which must be scheduled every day (or more frequently) to rebuild all fragmented indexes of a database and update all its statistics

## QueryExcelCsv.sql
A helper script which can be used to query CSV or XSLX files directly in Sql Management Studio without importing them into tables
