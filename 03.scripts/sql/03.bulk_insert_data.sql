/*
Bulking inserting with .csv files. 
AZURE free account expired... ;(
I'll continue the project with a normal database
*/

-- Use EXEC bronze_layer.procedure_bulk
CREATE OR ALTER PROCEDURE bronze_layer.procedure_bulk AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @start_batch_time DATETIME, @end_batch_time DATETIME

    BEGIN TRY
        -- This is to get the full stored procedure loading time
        SET @start_batch_time = GETDATE()

        -- TRUNCATE removes all rows from the table
        PRINT'   Truncating BREAKDOWN table';
        TRUNCATE TABLE bronze_layer.wel_breakdown_data;

        PRINT'===============================';
        PRINT'   Loading BREAKDOWN table...';
        PRINT'===============================';

        -- Start & End time to get the loading time in seconds
        SET @start_time = GETDATE()
        BULK INSERT bronze_layer.wel_breakdown_data
        FROM 'C:\Users\amcys\Documents\02.Education\01.Online Education\05.projects\manufacturing_data_warehousing\00.bulk_insert_data\wel_breakdown_data.csv'
        WITH (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a', -- If it fails, try 0x0d0a or /n
            TABLOCK
        );
        SET @end_time = GETDATE()
        PRINT'>> Loading Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds'
        PRINT'>> -----------'

        PRINT'   Truncating STATUS table';
        TRUNCATE TABLE bronze_layer.wel_status_data

        PRINT'===============================';
        PRINT'   Loading STATUS table...';
        PRINT'===============================';
        SET @start_time = GETDATE()
        BULK INSERT bronze_layer.wel_status_data
        FROM 'C:\Users\amcys\Documents\02.Education\01.Online Education\05.projects\manufacturing_data_warehousing\00.bulk_insert_data\wel_status_data.csv'
        WITH(
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a', -- If it fails, try 0x0d0a or /n
            TABLOCK
        );
        SET @end_time = GETDATE()
        PRINT'>> Loading Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds'
        PRINT'>> -----------'

        -- End of stored procedure processing time
        SET @end_batch_time = GETDATE()
        PRINT'>> Total Loading Duration: ' + CAST(DATEDIFF(second, @start_batch_time, @end_batch_time) AS NVARCHAR) + ' seconds'
        PRINT'>> -----------'
    END TRY

    BEGIN CATCH
        PRINT'=======================================';
        PRINT'ERROR OCCURED ON BRONZE LAYER LOADING';
        PRINT'Error Message:' + CAST(ERROR_MESSAGE() AS NVARCHAR);
        PRINT'Error Message:' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT'=======================================';
    END CATCH

END;
