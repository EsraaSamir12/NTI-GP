
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
            ticket_id,

            -- Correct created_at
            CASE
                WHEN resolved_at < created_at THEN resolved_at
                ELSE created_at
            END,

            issue_description, category, issue_type_id, product,
            channel, region, language, customer_name, customer_email,
            customer_age, customer_gender, subscription_type,
            customer_tenure_months, previous_tickets, customer_segment,
            priority, issue_complexity_score, assigned_team, assigned_to,
            status,

            COALESCE(escalated, N'Unknown'),
            COALESCE(escalation_reason, N'Unknown'),

            reopen_count,

            first_response_time_hours * 60.0,
            ABS(resolution_time_hours) * 60.0,
            paused_hours * 60.0,

            -- Calculate wall-clock minutes after correcting dates
            CASE
                WHEN created_at IS NULL OR resolved_at IS NULL
                    THEN NULL
                ELSE ABS(
                    DATEDIFF_BIG(SECOND, created_at, resolved_at)
                ) / 60.0
            END,

            -- Correct first_resolved_at
            CASE
                WHEN first_resolved_at >
                    CASE
                        WHEN resolved_at < created_at THEN created_at
                        ELSE resolved_at
                    END
                THEN
                    CASE
                        WHEN resolved_at < created_at THEN resolved_at
                        ELSE created_at
                    END
                ELSE first_resolved_at
            END,

            -- Correct resolved_at
            CASE
                WHEN first_resolved_at >
                    CASE
                        WHEN resolved_at < created_at THEN created_at
                        ELSE resolved_at
                    END
                THEN first_resolved_at
                WHEN resolved_at < created_at THEN created_at
                ELSE resolved_at
            END,

            closed_at,
            resolved_by,
            resolution_notes,

            sla_target_hours * 60.0,
            sla_breached,
            sla_breach_margin * 60.0,

            customer_satisfaction_score

        FROM Bronze.SupportTicket;

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

-- Execute the procedure
EXEC Silver.silver_Load;
GO

-- Check row counts
SELECT
    (SELECT COUNT(*) FROM Bronze.SupportTicket) AS BronzeRows,
    (SELECT COUNT(*) FROM Silver.SupportTicket) AS SilverRows;
GO


----------------------------------------------------------------------------


