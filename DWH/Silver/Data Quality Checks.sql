-- Data Quality Checks 


-- Checks Duplicates  --> count = 0
SELECT COUNT(*) AS [Duplication count], ticket_id
FROM Bronze.SupportTicket
GROUP BY ticket_id
HAVING COUNT(*) > 1;

-- check missing values for each row 
DECLARE @SQL NVARCHAR(MAX) = '';

SELECT @SQL = @SQL +
    CASE WHEN @SQL = '' THEN '' ELSE ' UNION ALL ' END +
    'SELECT ''' + COLUMN_NAME + ''' AS ColumnName, ' +
    'COUNT(*) AS NullCount ' +
    'FROM Bronze.SupportTicket ' +
    'WHERE [' + COLUMN_NAME + '] IS NULL'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Bronze'
  AND TABLE_NAME = 'SupportTicket';

SET @SQL = @SQL + ' ORDER BY NullCount DESC;';

EXEC sp_executesql @SQL;



-- Check Unique Values
SELECT DISTINCT category
FROM Bronze.SupportTicket;

SELECT DISTINCT product
FROM Bronze.SupportTicket;

SELECT DISTINCT channel
FROM Bronze.SupportTicket;

SELECT DISTINCT region
FROM Bronze.SupportTicket;

SELECT DISTINCT language
FROM Bronze.SupportTicket;

SELECT DISTINCT subscription_type
FROM Bronze.SupportTicket;

SELECT DISTINCT customer_segment
FROM Bronze.SupportTicket;

SELECT DISTINCT priority
FROM Bronze.SupportTicket;

SELECT DISTINCT assigned_team
FROM Bronze.SupportTicket;

SELECT DISTINCT status
FROM Bronze.SupportTicket;

SELECT DISTINCT escalated
FROM Bronze.SupportTicket;

SELECT DISTINCT gender
FROM Bronze.SupportTicket;


-------------------------

SELECT
    MIN(customer_age) AS min_customer_age,
    MAX(customer_age) AS max_customer_age,

    MIN(customer_tenure_months) AS min_tenure,
    MAX(customer_tenure_months) AS max_tenure,

    MIN(previous_tickets) AS min_previous_tickets,
    MAX(previous_tickets) AS max_previous_tickets,

    MIN(issue_complexity_score) AS min_complexity,
    MAX(issue_complexity_score) AS max_complexity,

    MIN(reopen_count) AS min_reopen_count,
    MAX(reopen_count) AS max_reopen_count,

    MIN(first_response_time_hours) AS min_first_response,
    MAX(first_response_time_hours) AS max_first_response,

    MIN(resolution_time_hours) AS min_resolution_time,
    MAX(resolution_time_hours) AS max_resolution_time,

    MIN(paused_hours) AS min_paused_hours,
    MAX(paused_hours) AS max_paused_hours,

    MIN(resolution_wallclock_hours) AS min_wallclock,
    MAX(resolution_wallclock_hours) AS max_wallclock

FROM Bronze.SupportTicket;

---------------------------------------------------------------

WITH Comparison AS (
    SELECT
        ticket_id,
        created_at,
        resolved_at,
        resolution_wallclock_hours AS original_hours,

        DATEDIFF(
            SECOND,
            TRY_CONVERT(DATETIME, created_at),
            TRY_CONVERT(DATETIME, resolved_at)
        ) / 3600.0 AS calculated_hours

    FROM Bronze.SupportTicket
    WHERE TRY_CONVERT(DATETIME, created_at) IS NOT NULL
      AND TRY_CONVERT(DATETIME, resolved_at) IS NOT NULL
)
SELECT
    *,
    original_hours - calculated_hours AS difference_hours
FROM Comparison
WHERE original_hours IS NULL
   OR ABS(original_hours - calculated_hours) > 1;


-------------------------------------------------------

SELECT COUNT(*) AS resolved_before_created
FROM Bronze.SupportTicket
WHERE TRY_CONVERT(DATETIME, created_at) IS NOT NULL
  AND TRY_CONVERT(DATETIME, resolved_at) IS NOT NULL
  AND TRY_CONVERT(DATETIME, resolved_at)
      < TRY_CONVERT(DATETIME, created_at);

---------------------------------------------------------
SELECT
    ticket_id,
    created_at,
    first_resolved_at,
    resolved_at
FROM Bronze.SupportTicket
WHERE TRY_CONVERT(DATETIME, first_resolved_at) IS NOT NULL
  AND TRY_CONVERT(DATETIME, resolved_at) IS NOT NULL
  AND TRY_CONVERT(DATETIME, first_resolved_at)
      > TRY_CONVERT(DATETIME, resolved_at);