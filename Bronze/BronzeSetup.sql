-- Create DWH
CREATE DATABASE IT_Solution_DWH

-- Create Schema
CREATE SCHEMA Bronze;
GO
CREATE SCHEMA Silver;
GO
CREATE SCHEMA Gold;
GO

-- Bronze(Staging Area)
IF OBJECT_ID('Bronze.SupportTicket', 'U') IS NOT NULL
    DROP TABLE Bronze.SupportTicket;

CREATE TABLE Bronze.SupportTicket (
    ticket_id INT,
    created_at DATETIME2,
    issue_description NVARCHAR(MAX),
    category NVARCHAR(MAX),
    issue_type_id INT,
    product NVARCHAR(MAX),
    channel NVARCHAR(MAX),
    region NVARCHAR(MAX),
    language NVARCHAR(MAX),
    customer_name NVARCHAR(MAX),
    customer_email NVARCHAR(MAX),
    customer_age INT,
    customer_gender NVARCHAR(MAX),
    subscription_type NVARCHAR(MAX),
    customer_tenure_months INT,
    previous_tickets INT,
    customer_segment NVARCHAR(MAX),
    priority NVARCHAR(MAX),
    issue_complexity_score DECIMAL(10,2),
    assigned_team NVARCHAR(MAX),
    assigned_to NVARCHAR(MAX),
    status NVARCHAR(MAX),
    escalated NVARCHAR(MAX),
    escalation_reason NVARCHAR(MAX),
    reopen_count INT,
    first_response_time_hours DECIMAL(18,2),
    resolution_time_hours DECIMAL(18,2),
    paused_hours DECIMAL(18,2),
    resolution_wallclock_hours DECIMAL(18,2),
    first_resolved_at DATETIME2,
    resolved_at DATETIME2,
    closed_at DATETIME2,
    resolved_by NVARCHAR(MAX),
    resolution_notes NVARCHAR(MAX),
    sla_target_hours DECIMAL(18,2),
    sla_breached NVARCHAR(MAX),
    sla_breach_margin DECIMAL(18,2),
    customer_satisfaction_score DECIMAL(5,2)
);
