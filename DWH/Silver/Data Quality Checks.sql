-- Data Quality Checks 


-- Checks Duplicates  --> count = 0
SELECT COUNT(*) AS [Duplication count], ticket_id
FROM Bronze.SupportTicket
GROUP BY ticket_id
HAVING COUNT(*) > 1;

-- check missing values for each row 
SELECT
    COUNT(*) - COUNT(ticket_id) AS ticket_id_Nulls,
    COUNT(*) - COUNT(created_at) AS created_at_Nulls,
    COUNT(*) - COUNT(issue_description) AS issue_description_Nulls,
    COUNT(*) - COUNT(category) AS category_Nulls,
    COUNT(*) - COUNT(issue_type_id) AS issue_type_id_Nulls,
    COUNT(*) - COUNT(product) AS product_Nulls,
    COUNT(*) - COUNT(channel) AS channel_Nulls,
    COUNT(*) - COUNT(region) AS region_Nulls,
    COUNT(*) - COUNT(language) AS language_Nulls,
    COUNT(*) - COUNT(customer_name) AS customer_name_Nulls,
    COUNT(*) - COUNT(customer_email) AS customer_email_Nulls,
    COUNT(*) - COUNT(customer_age) AS customer_age_Nulls,
    COUNT(*) - COUNT(customer_gender) AS customer_gender_Nulls,
    COUNT(*) - COUNT(subscription_type) AS subscription_type_Nulls,
    COUNT(*) - COUNT(customer_tenure_months) AS customer_tenure_months_Nulls,
    COUNT(*) - COUNT(previous_tickets) AS previous_tickets_Nulls,
    COUNT(*) - COUNT(customer_segment) AS customer_segment_Nulls,
    COUNT(*) - COUNT(priority) AS priority_Nulls,
    COUNT(*) - COUNT(issue_complexity_score) AS issue_complexity_score_Nulls,
    COUNT(*) - COUNT(assigned_team) AS assigned_team_Nulls,
    COUNT(*) - COUNT(assigned_to) AS assigned_to_Nulls,
    COUNT(*) - COUNT(status) AS status_Nulls,
    COUNT(*) - COUNT(escalated) AS escalated_Nulls,
    COUNT(*) - COUNT(escalation_reason) AS escalation_reason_Nulls,
    COUNT(*) - COUNT(reopen_count) AS reopen_count_Nulls,
    COUNT(*) - COUNT(first_response_time_hours) AS first_response_time_hours_Nulls,
    COUNT(*) - COUNT(resolution_time_hours) AS resolution_time_hours_Nulls,
    COUNT(*) - COUNT(paused_hours) AS paused_hours_Nulls,
    COUNT(*) - COUNT(resolution_wallclock_hours) AS resolution_wallclock_hours_Nulls,
    COUNT(*) - COUNT(first_resolved_at) AS first_resolved_at_Nulls,
    COUNT(*) - COUNT(resolved_at) AS resolved_at_Nulls,
    COUNT(*) - COUNT(closed_at) AS closed_at_Nulls,
    COUNT(*) - COUNT(resolved_by) AS resolved_by_Nulls,
    COUNT(*) - COUNT(resolution_notes) AS resolution_notes_Nulls,
    COUNT(*) - COUNT(sla_target_hours) AS sla_target_hours_Nulls,
    COUNT(*) - COUNT(sla_breached) AS sla_breached_Nulls,
    COUNT(*) - COUNT(sla_breach_margin) AS sla_breach_margin_Nulls,
    COUNT(*) - COUNT(customer_satisfaction_score) AS customer_satisfaction_score_Nulls
FROM Bronze.SupportTicket;



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

SELECT DISTINCT customer_gender
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
    -------------------------------------------------------
    MIN(resolution_time_hours) AS min_resolution_time,
    MAX(resolution_time_hours) AS max_resolution_time,
    -------------------------------------------------------
    MIN(paused_hours) AS min_paused_hours,
    MAX(paused_hours) AS max_paused_hours,

    MIN(resolution_wallclock_hours) AS min_wallclock,
    MAX(resolution_wallclock_hours) AS max_wallclock

FROM Bronze.SupportTicket;

---------------------------------------------------------------
-- Validate resolution_wallclock_hours by identifying missing values or differences greater than 1 hour compared to the calculated duration.
WITH Comparison AS (
    SELECT
        ticket_id,
        created_at,
        resolved_at,
        resolution_wallclock_hours AS original_hours,

        DATEDIFF(
            SECOND,
            created_at,
            resolved_at
        ) / 3600.0 AS calculated_hours

    FROM Bronze.SupportTicket
    WHERE created_at IS NOT NULL
      AND resolved_at IS NOT NULL
)
SELECT
    *,
    original_hours - calculated_hours AS difference_hours
FROM Comparison
WHERE original_hours IS NULL
   OR ABS(original_hours - calculated_hours) > 1;


-------------------------------------------------------
-- Count tickets where the resolution timestamp is earlier than the creation timestamp.
SELECT COUNT(*) AS resolved_before_created
FROM Bronze.SupportTicket
WHERE  created_at IS NOT NULL
  AND  resolved_at IS NOT NULL
  AND  resolved_at
      < created_at;

--------------------------------------------------------------------
-- Identify tickets where first_resolved_at is later than resolved_at.
SELECT count(*)
FROM Bronze.SupportTicket
WHERE first_resolved_at IS NOT NULL
  AND resolved_at IS NOT NULL
  AND first_resolved_at
      > resolved_at;
-----------------------------------------------------------------------
-- Tickets that exceeded the SLA target but are marked as not breached.
SELECT COUNT(*) AS SLA_Inconsistency_Count
FROM Bronze.SupportTicket
WHERE created_at IS NOT NULL
  AND resolved_at IS NOT NULL
  AND DATEDIFF(
        SECOND,
        created_at,
        resolved_at
      ) / 3600.0 > sla_target_hours
  AND sla_breached = 'No';


-- Tickets resolved within the SLA target but marked as breached.  
SELECT COUNT(*) AS SLA_Inconsistency_Count
FROM Bronze.SupportTicket
WHERE created_at IS NOT NULL
  AND resolved_at IS NOT NULL
  AND DATEDIFF(
        SECOND,
        created_at,
        resolved_at
      ) / 3600.0 < sla_target_hours
  AND sla_breached = 'Yes';
