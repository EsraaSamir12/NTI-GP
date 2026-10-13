
CREATE OR ALTER PROCEDURE Bronze.bronze_Load
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @Start_Time DATETIME,
        @End_Time DATETIME;

    BEGIN TRY

        PRINT '>> Loading The Bronze Layer';

        SET @Start_Time = GETDATE();

        PRINT '>> Truncating table Bronze.SupportTicket';

        TRUNCATE TABLE Bronze.SupportTicket;

        PRINT '>> Inserting data from CSV into Bronze.SupportTicket';

        BULK INSERT Bronze.SupportTicket
        FROM 'D:\NTI GP\tickets.csv'
        WITH
        (
             FIRSTROW = 2, 
             FIELDTERMINATOR = ',', 
             ROWTERMINATOR = '\n',  
             CODEPAGE = '65001',    
             TABLOCK
        );

        SET @End_Time = GETDATE();

        PRINT '>> Bronze Layer Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @Start_Time, @End_Time)
                AS NVARCHAR(20)
            )
            + ' seconds';

        PRINT '>> Bronze Layer Loading Completed';
        PRINT '-----------------------------------------';

    END TRY

    BEGIN CATCH

        PRINT '>> ERROR OCCURRED DURING LOADING THE BRONZE LAYER';

        PRINT '>> ERROR MESSAGE: ' + ERROR_MESSAGE();

        PRINT '>> ERROR LINE: '
            + CAST(ERROR_LINE() AS NVARCHAR(20));

        PRINT '-----------------------------------------';

        THROW;

    END CATCH
END;
GO

-- Execute Procedure
EXEC Bronze.bronze_Load;
GO

-- Check Loaded Data
SELECT COUNT(*) AS TotalRows
FROM Bronze.SupportTicket;

SELECT TOP 10 *
FROM Bronze.SupportTicket;
GO


