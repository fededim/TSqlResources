-- © 2020 Federico Di Marco <fededim@gmail.com>

CREATE OR ALTER FUNCTION fnGetCalendarTable
(@startDate datetime2,
 @endDate datetime2,
 @stepMin int=1440)
 RETURNS TABLE
 AS
 RETURN 
  WITH seq(n,ts) AS 
	(
	  SELECT 0,@startDate UNION ALL SELECT n+1,DATEADD(minute, (n+1)*@stepMin, @startDate) FROM seq
	  WHERE  DATEADD(minute, (n+1)*@stepMin, @startDate)<=@endDate
	)
	SELECT
		[Timestamp]         = ts,
		[Day]          = DATEPART(DAY,       ts),
		[DayName]      = DATENAME(WEEKDAY,   ts),
		[Week]         = DATEPART(WEEK,      ts),
		[ISOWeek]      = DATEPART(ISO_WEEK,  ts),
		[DayOfWeek]    = DATEPART(WEEKDAY,   ts),
		[Month]        = DATEPART(MONTH,     ts),
		[MonthName]    = DATENAME(MONTH,     ts),
		[Quarter]      = DATEPART(Quarter,   ts),
		[Year]         = DATEPART(YEAR,      ts),
		[DayOfYear]    = DATEPART(DAYOFYEAR, ts),
		[Hour]		   = DATEPART(HOUR,ts),
		[Minute]	   = DATEPART(MINUTE,ts),
		[Second]	   = DATEPART(SECOND,ts),
		[Millisecond]  = DATEPART(MILLISECOND,ts),
		[Microsecond]  = DATEPART(MICROSECOND,ts)
	  FROM seq
-- ORDER BY [ts]
-- OPTION (MAXRECURSION 0);


-- SELECT * FROM fnGetCalendarTable('2020-08-12T08:01:33.123456','2020-08-13T09:15:22',10) OPTION (MAXRECURSION 0)