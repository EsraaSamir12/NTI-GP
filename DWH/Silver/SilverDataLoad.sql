CREATE OR ALTER PROCEDURE Silver.silver_Load
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        PRINT '>> Loading Silver Layer';

        TRUNCATE TABLE Silver.SupportTicket;

        INSERT INTO Silver.SupportTicket
        (
            ticket_id, created_at, issue_description, category,
            issue_type_id, product, channel, region, language,
            customer_name, customer_email, customer_age,
            customer_gender, subscription_type, customer_tenure_months,
            previous_tickets, customer_segment, priority,
            issue_complexity_score, assigned_team, assigned_to, status,
            escalated, escalation_reason, reopen_count,
            first_response_time_minutes, resolution_time_minutes,
            paused_minutes, resolution_wallclock_minutes,
            first_resolved_at, resolved_at, closed_at, resolved_by,
            resolution_notes, sla_target_minutes, sla_breached,
            sla_breach_margin_minutes, customer_satisfaction_score
        )
        SELECT
            b.ticket_id,

            CASE
                WHEN b.resolved_at < b.created_at THEN b.resolved_at
                ELSE b.created_at
            END,

            b.issue_description, b.category, b.issue_type_id,
            b.product, b.channel, b.region, b.language,
            b.customer_name, b.customer_email, b.customer_age,
            b.customer_gender, b.subscription_type,
            b.customer_tenure_months, b.previous_tickets,
            b.customer_segment, b.priority, b.issue_complexity_score,
            b.assigned_team, b.assigned_to, b.status,

            COALESCE(b.escalated, N'Unknown'),
            COALESCE(b.escalation_reason, N'Unknown'),

            b.reopen_count,
            b.first_response_time_hours * 60.0,
            ABS(b.resolution_time_hours) * 60.0,
            b.paused_hours * 60.0,

            calc.resolution_wallclock_minutes,

            CASE
                WHEN b.first_resolved_at > dates.latest_date
                THEN dates.earliest_date
                ELSE b.first_resolved_at
            END,

            dates.latest_date,

            b.closed_at,
            CASE
            WHEN b.resolved_by IS NULL THEN 'Not Resolved Yet'
                 ELSE b.resolved_by
            END AS resolved_by,
            b.resolution_notes,

            b.sla_target_hours * 60.0,

            CASE
                WHEN calc.sla_breach_margin_minutes < 0 THEN 'Yes'
                WHEN calc.sla_breach_margin_minutes > 0 THEN 'No'
                ELSE 'Pending'
            END,

            calc.sla_breach_margin_minutes,

            b.customer_satisfaction_score

        FROM Bronze.SupportTicket b

        CROSS APPLY (
            SELECT
                CASE
                    WHEN b.resolved_at < b.created_at THEN b.resolved_at
                    ELSE b.created_at
                END AS earliest_date,

                CASE
                    WHEN b.resolved_at < b.created_at THEN b.created_at
                    ELSE b.resolved_at
                END AS latest_date
        ) dates

        CROSS APPLY (
            SELECT
                CASE
                    WHEN b.created_at IS NULL OR b.resolved_at IS NULL
                    THEN NULL
                    ELSE ABS(
                        DATEDIFF_BIG(SECOND, dates.earliest_date, dates.latest_date)
                    ) / 60.0
                END AS resolution_wallclock_minutes
        ) wallclock

        CROSS APPLY (
            SELECT
                wallclock.resolution_wallclock_minutes,
                CASE
                    WHEN b.resolved_at IS NULL
                         OR b.sla_target_hours IS NULL
                         OR wallclock.resolution_wallclock_minutes IS NULL
                    THEN NULL
                    ELSE (b.sla_target_hours * 60.0)
                         - wallclock.resolution_wallclock_minutes
                END AS sla_breach_margin_minutes
        ) calc;

        COMMIT TRANSACTION;

        PRINT '>> Silver Layer Load Completed';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        PRINT '>> ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

EXEC Silver.silver_Load;
GO

SELECT
    (SELECT COUNT(*) FROM Bronze.SupportTicket) AS BronzeRows,
    (SELECT COUNT(*) FROM Silver.SupportTicket) AS SilverRows;
GO


