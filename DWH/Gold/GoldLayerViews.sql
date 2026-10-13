
/*========================================================
  GOLD LAYER - SUPPORT TICKETS STAR SCHEMA
  Source: Silver.SupportTicket
  All Gold objects are Views
========================================================*/


/*========================================================
  1. DIM DATE
========================================================*/

-- DimDate

CREATE OR ALTER VIEW Gold.DimDate
AS
WITH DateBounds AS (
    SELECT
        DATEFROMPARTS(YEAR(MIN(AllDates.FullDate)), 1, 1) AS StartDate,
        DATEFROMPARTS(YEAR(MAX(AllDates.FullDate)), 12, 31) AS EndDate
    FROM (
        SELECT CAST(created_at AS DATE) AS FullDate
        FROM Silver.SupportTicket

        UNION ALL

        SELECT CAST(first_resolved_at AS DATE)
        FROM Silver.SupportTicket

        UNION ALL

        SELECT CAST(resolved_at AS DATE)
        FROM Silver.SupportTicket

        UNION ALL

        SELECT CAST(closed_at AS DATE)
        FROM Silver.SupportTicket
    ) AS AllDates
    WHERE AllDates.FullDate IS NOT NULL
),
Numbers AS (
    SELECT TOP (
        SELECT DATEDIFF(DAY, StartDate, EndDate) + 1
        FROM DateBounds
    )
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.objects AS a
    CROSS JOIN sys.objects AS b
)
SELECT
    CONVERT(INT, FORMAT(DATEADD(DAY, n, StartDate), 'yyyyMMdd')) AS DateKey,
    CAST(DATEADD(DAY, n, StartDate) AS DATE) AS FullDate,
    DATENAME(MONTH, DATEADD(DAY, n, StartDate)) AS MonthName,
    DATEPART(MONTH, DATEADD(DAY, n, StartDate)) AS MonthNumber,
    DATEPART(QUARTER, DATEADD(DAY, n, StartDate)) AS QuarterNumber,
    DATEPART(YEAR, DATEADD(DAY, n, StartDate)) AS YearNumber,
    DATEPART(ISO_WEEK, DATEADD(DAY, n, StartDate)) AS WeekNumber,
    DATENAME(WEEKDAY, DATEADD(DAY, n, StartDate)) AS DayName,
    DATEPART(DAY, DATEADD(DAY, n, StartDate)) AS DayNumber
FROM Numbers
CROSS JOIN DateBounds;


/*========================================================
  2. DIM ISSUE
========================================================*/

CREATE OR ALTER VIEW Gold.DimIssue AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY Category, IssueType
    ) AS IssueKey,
    Category,
    IssueType
FROM (
    SELECT DISTINCT
        category AS Category,
        issue_type_id AS IssueType
    FROM Silver.SupportTicket
) AS Issues;
GO

select * from Gold.DimIssue
/*========================================================
  3. DIM CUSTOMER
========================================================*/

CREATE OR ALTER VIEW Gold.DimCustomer AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            CustomerName,
            CustomerEmail,
            CustomerAge,
            CustomerGender,
            SubscriptionType,
            CustomerTenureMonths,
            CustomerSegment
    ) AS CustomerKey,
    CustomerName,
    CustomerEmail,
    CustomerAge,
    CustomerGender,
    SubscriptionType,
    CustomerTenureMonths,
    CustomerSegment
FROM (
    SELECT DISTINCT
        customer_name AS CustomerName,
        customer_email AS CustomerEmail,
        customer_age AS CustomerAge,
        customer_gender AS CustomerGender,
        subscription_type AS SubscriptionType,
        customer_tenure_months AS CustomerTenureMonths,
        customer_segment AS CustomerSegment
    FROM Silver.SupportTicket
) AS Customers;
GO

SELECT
    COUNT_BIG(*) AS TotalRows,
    COUNT_BIG(*) - COUNT(CustomerName) AS NullCustomerName,
    COUNT_BIG(*) - COUNT(CustomerEmail) AS NullCustomerEmail,
    COUNT_BIG(*) - COUNT(CustomerAge) AS NullCustomerAge,
    COUNT_BIG(*) - COUNT(CustomerGender) AS NullCustomerGender,
    COUNT_BIG(*) - COUNT(SubscriptionType) AS NullSubscriptionType,
    COUNT_BIG(*) - COUNT(CustomerTenureMonths) AS NullCustomerTenureMonths,
    COUNT_BIG(*) - COUNT(CustomerSegment) AS NullCustomerSegment
FROM Gold.DimCustomer;
/*========================================================
  4. DIM TICKET CONTEXT
========================================================*/

CREATE OR ALTER VIEW Gold.DimTicketContext AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY product, channel, region, language
    ) AS TicketContextKey,
    product,
    channel,
    region,
    language
FROM (
    SELECT DISTINCT
        product,
        channel,
        region,
        language
    FROM Silver.SupportTicket
) AS TicketContexts;
GO
/*========================================================
  5. DIM STAFF
========================================================*/
CREATE OR ALTER VIEW Gold.DimStaff AS
WITH StaffMembers AS (
    SELECT
        assigned_team AS AssignedTeam,
        assigned_to AS Member
    FROM Silver.SupportTicket
    WHERE assigned_to IS NOT NULL

    UNION

    SELECT
        assigned_team AS AssignedTeam,
        resolved_by AS Member
    FROM Silver.SupportTicket
    WHERE resolved_by IS NOT NULL
),
UniqueStaff AS (
    SELECT
        AssignedTeam,
        Member,
        ROW_NUMBER() OVER (
            PARTITION BY Member
            ORDER BY AssignedTeam
        ) AS rn
    FROM StaffMembers
)
SELECT
    ROW_NUMBER() OVER (
        ORDER BY AssignedTeam, Member
    ) AS StaffKey,
    AssignedTeam,
    Member
FROM UniqueStaff
WHERE rn = 1

UNION ALL

SELECT
    1 AS StaffKey,
    CAST(NULL AS NVARCHAR(MAX)) AS AssignedTeam,
    CAST(NULL AS NVARCHAR(MAX)) AS Member
WHERE NOT EXISTS (
    SELECT 1
    FROM UniqueStaff
    WHERE Member IS NULL
);
GO

/*========================================================
  6. DIM TICKET STATE
========================================================*/

CREATE OR ALTER VIEW Gold.DimTicketState AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY Priority, Status
    ) AS TicketStateKey,
    Priority,
    Status
FROM (
    SELECT DISTINCT
        priority AS Priority,
        status AS Status
    FROM Silver.SupportTicket
) AS TicketStates;
GO

select * from Gold.DimTicketState
/*========================================================
  7. DIM TICKET FLAGS
========================================================*/

CREATE OR ALTER VIEW Gold.DimTicketFlags AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY escalated, SlaBreached
    ) AS FlagsKey,
    escalated,
    SlaBreached
FROM (
    SELECT DISTINCT
        escalated,
        sla_breached AS SlaBreached
    FROM Silver.SupportTicket
) AS TicketFlags;
GO

select * from  Gold.DimTicketFlags
/*========================================================
  8. FACT TICKETS
========================================================*/

CREATE OR ALTER VIEW Gold.FactTickets AS
WITH TicketData AS (
    SELECT
        S.ticket_id AS TicketId,

        I.IssueKey,
        C.CustomerKey,
        TC.TicketContextKey,
        F.FlagsKey,

        AssignedStaff.StaffKey AS AssignedAtKey,

        COALESCE(
            ResolvedStaff.StaffKey,
            UnknownStaff.StaffKey
        ) AS ResolvedByKey,

        TS.TicketStateKey,

        COALESCE(CreatedDate.DateKey, 0) AS CreatedAtKey,

        COALESCE(
            FirstResolvedDate.DateKey, 0
        ) AS FirstResolvedAtKey,

        COALESCE(
            ResolvedDate.DateKey, 0
        ) AS ResolvedAtKey,

        COALESCE(
            ClosedDate.DateKey, 0
        ) AS ClosedAtKey,

        CAST(
            ROUND(S.sla_target_minutes / 60.0, 0)
            AS INT
        ) AS SlaTargetHours,

        CAST(
            ROUND(S.sla_breach_margin_minutes, 0)
            AS INT
        ) AS SlaBreachMargin,

        CAST(
            ROUND(S.customer_satisfaction_score, 0)
            AS INT
        ) AS CustomerSatisfactionScore,

        S.resolution_notes AS ResolutionNotes,

        CAST(
            ROUND(S.resolution_wallclock_minutes, 0)
            AS INT
        ) AS ResolutionWallclockMinutes,

        CAST(
            ROUND(S.paused_minutes, 0)
            AS INT
        ) AS PausedMinutes,

        CAST(
            ROUND(S.resolution_time_minutes, 0)
            AS INT
        ) AS ResolutionTimeMinutes,

        CAST(
            ROUND(S.first_response_time_minutes, 0)
            AS INT
        ) AS FirstResponseTimeMinutes,

        S.reopen_count AS ReopenCount,
        S.escalation_reason AS EscalationReason,

        CAST(
            ROUND(S.issue_complexity_score, 0)
            AS INT
        ) AS IssueComplexityScore,

        S.issue_description AS IssueDescription

    FROM Silver.SupportTicket S

    /* Issue */
    INNER JOIN Gold.DimIssue I
        ON (
            I.Category = S.category
            OR (
                I.Category IS NULL
                AND S.category IS NULL
            )
        )
       AND (
            I.IssueType = S.issue_type_id
            OR (
                I.IssueType IS NULL
                AND S.issue_type_id IS NULL
            )
        )

    /* Customer */
    INNER JOIN Gold.DimCustomer C
        ON (
            C.CustomerName = S.customer_name
            OR (
                C.CustomerName IS NULL
                AND S.customer_name IS NULL
            )
        )
       AND (
            C.CustomerEmail = S.customer_email
            OR (
                C.CustomerEmail IS NULL
                AND S.customer_email IS NULL
            )
        )
       AND (
            C.CustomerAge = S.customer_age
            OR (
                C.CustomerAge IS NULL
                AND S.customer_age IS NULL
            )
        )
       AND (
            C.CustomerGender = S.customer_gender
            OR (
                C.CustomerGender IS NULL
                AND S.customer_gender IS NULL
            )
        )
       AND (
            C.SubscriptionType = S.subscription_type
            OR (
                C.SubscriptionType IS NULL
                AND S.subscription_type IS NULL
            )
        )
       AND (
            C.CustomerTenureMonths = S.customer_tenure_months
            OR (
                C.CustomerTenureMonths IS NULL
                AND S.customer_tenure_months IS NULL
            )
        )
       AND (
            C.CustomerSegment = S.customer_segment
            OR (
                C.CustomerSegment IS NULL
                AND S.customer_segment IS NULL
            )
        )

    /* Ticket Context */
    INNER JOIN Gold.DimTicketContext TC
        ON (
            TC.product = S.product
            OR (
                TC.product IS NULL
                AND S.product IS NULL
            )
        )
       AND (
            TC.channel = S.channel
            OR (
                TC.channel IS NULL
                AND S.channel IS NULL
            )
        )
       AND (
            TC.region = S.region
            OR (
                TC.region IS NULL
                AND S.region IS NULL
            )
        )
       AND (
            TC.language = S.language
            OR (
                TC.language IS NULL
                AND S.language IS NULL
            )
        )

    /* Ticket Flags */
    INNER JOIN Gold.DimTicketFlags F
        ON (
            F.escalated = S.escalated
            OR (
                F.escalated IS NULL
                AND S.escalated IS NULL
            )
        )
       AND (
            F.SlaBreached = S.sla_breached
            OR (
                F.SlaBreached IS NULL
                AND S.sla_breached IS NULL
            )
        )

    /* Assigned Staff */
    INNER JOIN Gold.DimStaff AssignedStaff
        ON (
            AssignedStaff.AssignedTeam = S.assigned_team
            OR (
                AssignedStaff.AssignedTeam IS NULL
                AND S.assigned_team IS NULL
            )
        )
       AND (
            AssignedStaff.Member = S.assigned_to
            OR (
                AssignedStaff.Member IS NULL
                AND S.assigned_to IS NULL
            )
        )

    /* Resolved By Staff */
    LEFT JOIN Gold.DimStaff ResolvedStaff
        ON ResolvedStaff.AssignedTeam IS NULL
       AND ResolvedStaff.Member = S.resolved_by

    /* Unknown Staff */
    CROSS JOIN (
        SELECT StaffKey
        FROM Gold.DimStaff
        WHERE AssignedTeam IS NULL
          AND Member IS NULL
    ) UnknownStaff

    /* Ticket State */
    INNER JOIN Gold.DimTicketState TS
        ON (
            TS.Priority = S.priority
            OR (
                TS.Priority IS NULL
                AND S.priority IS NULL
            )
        )
       AND (
            TS.Status = S.status
            OR (
                TS.Status IS NULL
                AND S.status IS NULL
            )
        )

    /* Date Dimensions */
    LEFT JOIN Gold.DimDate CreatedDate
        ON CreatedDate.FullDate =
           CAST(S.created_at AS DATE)

    LEFT JOIN Gold.DimDate FirstResolvedDate
        ON FirstResolvedDate.FullDate =
           CAST(S.first_resolved_at AS DATE)

    LEFT JOIN Gold.DimDate ResolvedDate
        ON ResolvedDate.FullDate =
           CAST(S.resolved_at AS DATE)

    LEFT JOIN G
/*========================================================
  GOLD LAYER - SUPPORT TICKETS STAR SCHEMA
  Source: Silver.SupportTicket
  All Gold objects are Views
========================================================*/


/*========================================================
  1. DIM DATE
========================================================*/

-- DimDate

CREATE OR ALTER VIEW Gold.DimDate
AS
WITH DateBounds AS (
    SELECT
        DATEFROMPARTS(YEAR(MIN(AllDates.FullDate)), 1, 1) AS StartDate,
        DATEFROMPARTS(YEAR(MAX(AllDates.FullDate)), 12, 31) AS EndDate
    FROM (
        SELECT CAST(created_at AS DATE) AS FullDate
        FROM Silver.SupportTicket

        UNION ALL

        SELECT CAST(first_resolved_at AS DATE)
        FROM Silver.SupportTicket

        UNION ALL

        SELECT CAST(resolved_at AS DATE)
        FROM Silver.SupportTicket

        UNION ALL

        SELECT CAST(closed_at AS DATE)
        FROM Silver.SupportTicket
    ) AS AllDates
    WHERE AllDates.FullDate IS NOT NULL
),
Numbers AS (
    SELECT TOP (
        SELECT DATEDIFF(DAY, StartDate, EndDate) + 1
        FROM DateBounds
    )
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.objects AS a
    CROSS JOIN sys.objects AS b
)
SELECT
    CONVERT(INT, FORMAT(DATEADD(DAY, n, StartDate), 'yyyyMMdd')) AS DateKey,
    CAST(DATEADD(DAY, n, StartDate) AS DATE) AS FullDate,
    DATENAME(MONTH, DATEADD(DAY, n, StartDate)) AS MonthName,
    DATEPART(MONTH, DATEADD(DAY, n, StartDate)) AS MonthNumber,
    DATEPART(QUARTER, DATEADD(DAY, n, StartDate)) AS QuarterNumber,
    DATEPART(YEAR, DATEADD(DAY, n, StartDate)) AS YearNumber,
    DATEPART(ISO_WEEK, DATEADD(DAY, n, StartDate)) AS WeekNumber,
    DATENAME(WEEKDAY, DATEADD(DAY, n, StartDate)) AS DayName,
    DATEPART(DAY, DATEADD(DAY, n, StartDate)) AS DayNumber
FROM Numbers
CROSS JOIN DateBounds;


/*========================================================
  2. DIM ISSUE
========================================================*/

CREATE OR ALTER VIEW Gold.DimIssue AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY Category, IssueType
    ) AS IssueKey,
    Category,
    IssueType
FROM (
    SELECT DISTINCT
        category AS Category,
        issue_type_id AS IssueType
    FROM Silver.SupportTicket
) AS Issues;
GO


/*========================================================
  3. DIM CUSTOMER
========================================================*/

CREATE OR ALTER VIEW Gold.DimCustomer AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            CustomerName,
            CustomerEmail,
            CustomerAge,
            CustomerGender,
            SubscriptionType,
            CustomerTenureMonths,
            CustomerSegment
    ) AS CustomerKey,
    CustomerName,
    CustomerEmail,
    CustomerAge,
    CustomerGender,
    SubscriptionType,
    CustomerTenureMonths,
    CustomerSegment
FROM (
    SELECT DISTINCT
        customer_name AS CustomerName,
        customer_email AS CustomerEmail,
        customer_age AS CustomerAge,
        customer_gender AS CustomerGender,
        subscription_type AS SubscriptionType,
        customer_tenure_months AS CustomerTenureMonths,
        customer_segment AS CustomerSegment
    FROM Silver.SupportTicket
) AS Customers;
GO


/*========================================================
  4. DIM TICKET CONTEXT
========================================================*/

CREATE OR ALTER VIEW Gold.DimTicketContext AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY product, channel, region, language
    ) AS TicketContextKey,
    product,
    channel,
    region,
    language
FROM (
    SELECT DISTINCT
        product,
        channel,
        region,
        language
    FROM Silver.SupportTicket
) AS TicketContexts;
GO


/*========================================================
  5. DIM STAFF
========================================================*/
CREATE OR ALTER VIEW Gold.DimStaff AS

WITH StaffMembers AS (

    SELECT
        assigned_team AS AssignedTeam,
        assigned_to AS Member
    FROM Silver.SupportTicket
    WHERE assigned_to IS NOT NULL
      AND assigned_to <> N'Not Resolved Yet'

    UNION

    SELECT
        assigned_team AS AssignedTeam,
        resolved_by AS Member
    FROM Silver.SupportTicket
    WHERE resolved_by IS NOT NULL
      AND resolved_by <> N'Not Resolved Yet'
),

FinalStaff AS (

    SELECT
        AssignedTeam,
        Member
    FROM StaffMembers

    UNION

    SELECT
        CAST(N'No Team' AS NVARCHAR(MAX)) AS AssignedTeam,
        CAST(N'Not Resolved Yet' AS NVARCHAR(MAX)) AS Member
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY AssignedTeam, Member
    ) AS StaffKey,
    AssignedTeam,
    Member
FROM FinalStaff;
GO

select * from Gold.DimStaff

/*========================================================
  6. DIM TICKET STATE
========================================================*/

CREATE OR ALTER VIEW Gold.DimTicketState AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY Priority, Status
    ) AS TicketStateKey,
    Priority,
    Status
FROM (
    SELECT DISTINCT
        priority AS Priority,
        status AS Status
    FROM Silver.SupportTicket
) AS TicketStates;
GO


/*========================================================
  7. DIM TICKET FLAGS
========================================================*/

CREATE OR ALTER VIEW Gold.DimTicketFlags AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY escalated, SlaBreached
    ) AS FlagsKey,
    escalated,
    SlaBreached
FROM (
    SELECT DISTINCT
        escalated,
        sla_breached AS SlaBreached
    FROM Silver.SupportTicket
) AS TicketFlags;
GO

select * from Gold.DimTicketFlags

/*========================================================
  8. FACT TICKETS
========================================================*/

CREATE OR ALTER VIEW Gold.FactTickets AS

WITH TicketData AS (
    SELECT
        S.ticket_id AS TicketId,

        I.IssueKey,
        C.CustomerKey,
        TC.TicketContextKey,
        F.FlagsKey,

        AssignedStaff.StaffKey AS AssignedAtKey,

        COALESCE(
            ResolvedStaff.StaffKey,
            UnknownStaff.StaffKey
        ) AS ResolvedByKey,

        TS.TicketStateKey,

        COALESCE(CreatedDate.DateKey, 0) AS CreatedAtKey,

        COALESCE(
            FirstResolvedDate.DateKey, 0
        ) AS FirstResolvedAtKey,

        COALESCE(
            ResolvedDate.DateKey, 0
        ) AS ResolvedAtKey,

        COALESCE(
            ClosedDate.DateKey, 0
        ) AS ClosedAtKey,

        CAST(
            ROUND(S.sla_target_minutes / 60.0, 0)
            AS INT
        ) AS SlaTargetHours,

        CAST(
            ROUND(S.sla_breach_margin_minutes, 0)
            AS INT
        ) AS SlaBreachMarginMinutes,

        CAST(
            ROUND(S.customer_satisfaction_score, 0)
            AS INT
        ) AS CustomerSatisfactionScore,

        S.resolution_notes AS ResolutionNotes,

        CAST(
            ROUND(S.resolution_wallclock_minutes, 0)
            AS INT
        ) AS ResolutionWallclockMinutes,

        CAST(
            ROUND(S.paused_minutes, 0)
            AS INT
        ) AS PausedMinutes,

        CAST(
            ROUND(S.resolution_time_minutes, 0)
            AS INT
        ) AS ResolutionTimeMinutes,

        CAST(
            ROUND(S.first_response_time_minutes, 0)
            AS INT
        ) AS FirstResponseTimeMinutes,

        S.reopen_count AS ReopenCount,
        S.escalation_reason AS EscalationReason,

        CAST(
            ROUND(S.issue_complexity_score, 0)
            AS INT
        ) AS IssueComplexityScore,

        S.issue_description AS IssueDescription

    FROM Silver.SupportTicket S

    /* Issue */
    INNER JOIN Gold.DimIssue I
        ON (
            I.Category = S.category
            OR (
                I.Category IS NULL
                AND S.category IS NULL
            )
        )
       AND (
            I.IssueType = S.issue_type_id
            OR (
                I.IssueType IS NULL
                AND S.issue_type_id IS NULL
            )
        )

    /* Customer */
    INNER JOIN Gold.DimCustomer C
        ON (
            C.CustomerName = S.customer_name
            OR (
                C.CustomerName IS NULL
                AND S.customer_name IS NULL
            )
        )
       AND (
            C.CustomerEmail = S.customer_email
            OR (
                C.CustomerEmail IS NULL
                AND S.customer_email IS NULL
            )
        )
       AND (
            C.CustomerAge = S.customer_age
            OR (
                C.CustomerAge IS NULL
                AND S.customer_age IS NULL
            )
        )
       AND (
            C.CustomerGender = S.customer_gender
            OR (
                C.CustomerGender IS NULL
                AND S.customer_gender IS NULL
            )
        )
       AND (
            C.SubscriptionType = S.subscription_type
            OR (
                C.SubscriptionType IS NULL
                AND S.subscription_type IS NULL
            )
        )
       AND (
            C.CustomerTenureMonths = S.customer_tenure_months
            OR (
                C.CustomerTenureMonths IS NULL
                AND S.customer_tenure_months IS NULL
            )
        )
       AND (
            C.CustomerSegment = S.customer_segment
            OR (
                C.CustomerSegment IS NULL
                AND S.customer_segment IS NULL
            )
        )

    /* Ticket Context */
    INNER JOIN Gold.DimTicketContext TC
        ON (
            TC.product = S.product
            OR (
                TC.product IS NULL
                AND S.product IS NULL
            )
        )
       AND (
            TC.channel = S.channel
            OR (
                TC.channel IS NULL
                AND S.channel IS NULL
            )
        )
       AND (
            TC.region = S.region
            OR (
                TC.region IS NULL
                AND S.region IS NULL
            )
        )
       AND (
            TC.language = S.language
            OR (
                TC.language IS NULL
                AND S.language IS NULL
            )
        )

    /* Ticket Flags */
    INNER JOIN Gold.DimTicketFlags F
        ON (
            F.escalated = S.escalated
            OR (
                F.escalated IS NULL
                AND S.escalated IS NULL
            )
        )
       AND (
            F.SlaBreached = S.sla_breached
            OR (
                F.SlaBreached IS NULL
                AND S.sla_breached IS NULL
            )
        )

    /* Assigned Staff */
    INNER JOIN Gold.DimStaff AssignedStaff
        ON (
            AssignedStaff.AssignedTeam = S.assigned_team
            OR (
                AssignedStaff.AssignedTeam IS NULL
                AND S.assigned_team IS NULL
            )
        )
       AND (
            AssignedStaff.Member = S.assigned_to
            OR (
                AssignedStaff.Member IS NULL
                AND S.assigned_to IS NULL
            )
        )

    /* Resolved By Staff */
    LEFT JOIN Gold.DimStaff ResolvedStaff
        ON ResolvedStaff.AssignedTeam IS NULL
       AND ResolvedStaff.Member = S.resolved_by

    /* Unknown Staff */
    CROSS JOIN (
        SELECT StaffKey
        FROM Gold.DimStaff
        WHERE AssignedTeam IS NULL
          AND Member IS NULL
    ) UnknownStaff

    /* Ticket State */
    INNER JOIN Gold.DimTicketState TS
        ON (
            TS.Priority = S.priority
            OR (
                TS.Priority IS NULL
                AND S.priority IS NULL
            )
        )
       AND (
            TS.Status = S.status
            OR (
                TS.Status IS NULL
                AND S.status IS NULL
            )
        )

    /* Date Dimensions */
    LEFT JOIN Gold.DimDate CreatedDate
        ON CreatedDate.FullDate =
           CAST(S.created_at AS DATE)

    LEFT JOIN Gold.DimDate FirstResolvedDate
        ON FirstResolvedDate.FullDate =
           CAST(S.first_resolved_at AS DATE)

    LEFT JOIN Gold.DimDate ResolvedDate
        ON ResolvedDate.FullDate =
           CAST(S.resolved_at AS DATE)

    LEFT JOIN Gold.DimDate ClosedDate
        ON ClosedDate.FullDate =
           CAST(S.closed_at AS DATE)
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY TicketId
    ) AS TicketKey,
    *
FROM TicketData;
GO
