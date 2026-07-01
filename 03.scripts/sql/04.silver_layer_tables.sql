/*
================================================================================================
                                    SILVER LAYER
================================================================================================
DATABASE:   db_manufacturing_warehouse
SCHEMA:     silver_layer
------------------------------------------------------------------------------------------------
PURPOSE:    Reads raw production data from the bronze_layer, cleans and standardizes it,
            and structures it into a star schema (dimension + fact tables) ready for the
            gold layer's OEE calculations and aggregations.

OUTPUT:     Dimensions  ->  dim_date_dev
                            dim_work_stations_dev
                            dim_failures_dev
                            dim_product_dev
                            dim_team_leaders_status_dev
                            dim_product_details_dev
            Facts       ->  fact_breakdown_table_dev
                            fact_status_table_dev

NOTES:      - All tables carry the _dev suffix and are used for testing.
            - Script is idempotent: each table is dropped and recreated on every run.
            - Date and product dimensions are populated from BOTH source tables (UNION)
            to guarantee no fact rows are dropped on a missing dimension key.

------------------------------------------------------------------------------------------------
AUTHOR:     Eduardo Cysne
STARTED:    25/05/2026
================================================================================================
*/

/*
==============================================================
                    0.1 STAGING FACT TABLE
==============================================================
*/

-- Staging cleaned breakdown data
-- The staging serves as a single source of truth
-- Where all the data that will go to the dim_tables, will be cleaned and temporarily stored here
DROP TABLE IF EXISTS silver_layer.stg_breakdown;
SELECT
    b.ID                                               AS source_id,
    CONVERT(date, b.[date], 103)                       AS full_date,
    ISNULL(NULLIF(TRIM(b.work_station), ''), 'N/A')    AS work_station,
    ISNULL(NULLIF(TRIM(b.equipment),    ''), 'N/A')    AS equipment,
    ISNULL(NULLIF(TRIM(b.failure_type), ''), 'N/A')    AS failure_type,
    ISNULL(NULLIF(TRIM(b.sub_code),     ''), 'N/A')    AS sub_code,
    TRIM(b.line)                                       AS full_line,
    b.event_time,
    b.unplanned_downtime,
    b.planned_downtime,
    b.failure_description
INTO silver_layer.stg_breakdown
FROM bronze_layer.wel_breakdown_data b;
GO

/*
==============================================================
                    0.2 STAGING STATUS TABLE
==============================================================
*/
DROP TABLE IF EXISTS silver_layer.stg_status;
SELECT
    b.ID                                               AS source_id,
    CONVERT(date, b.[date], 103)                       AS full_date,
    TRIM(b.line)                                       AS full_line,
    REPLACE(TRIM(b.shift), 'night', 'evening')         AS shift,
    TRIM(b.team_leader)                                AS team_leader,
    b.num_operators,
    CASE WHEN TRIM(b.shift) = 'night' THEN 450 ELSE 480 END AS all_time,
    b.total_expected_output,
    b.total_produced,
    b.nok_parts,
    b.reworked_parts,
    b.accidents,
    b.near_accidents,
    b.customer_complaints,
    -- collapse repeated whitespaces:
    REPLACE(REPLACE(REPLACE(TRIM(b.observations), ' ', '<>'), '><', ''), '<>', ' ') AS observations,
    b.version,
    b.cycle_time
INTO silver_layer.stg_status
FROM bronze_layer.wel_status_data b;
GO


/*
==============================================================
            1.SILVER LAYER DATE DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_date_dev;
CREATE TABLE silver_layer.dim_date_dev (
    -- IDENTITY(1,1) makes the table autogenerate data starting from 1 and incrementing by 1
    date_id            INT IDENTITY(1,1) PRIMARY KEY,
    full_date          DATE NOT NULL,
    date_key           INT NOT NULL,
    day_num            INT NOT NULL,
    day_name           VARCHAR(50) NOT NULL,
    week_num           INT NOT NULL,
    week_name          VARCHAR(50) NOT NULL,
    month_num          INT NOT NULL,
    month_name         VARCHAR(50) NOT NULL,
    quarter_num        INT NOT NULL,
    quarter_name       VARCHAR(50) NOT NULL,
    year_num           INT NOT NULL,
    met_date_created   DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);
GO

-- Populating dim_date_dev table
INSERT INTO silver_layer.dim_date_dev(full_date, date_key, day_num, day_name, week_num, week_name, month_num, month_name, quarter_num, quarter_name, year_num)
SELECT
    d.full_date,
    CONVERT(INT, CONVERT(CHAR(8), d.full_date, 112)),  -- style 112 = YYYYMMDD (20250815)
    DATEPART(day, d.full_date),
    DATENAME(weekday, d.full_date),
    DATEPART(ISO_WEEK, d.full_date),
    'W' + FORMAT(DATEPART(ISO_WEEK, d.full_date), '00'),
    DATEPART(month, d.full_date),
    DATENAME(month, d.full_date),
    DATEPART(quarter, d.full_date),
    'Q' + CAST(DATEPART(quarter, d.full_date) AS VARCHAR(1)),
    DATEPART(year, d.full_date)
FROM (
    SELECT full_date FROM silver_layer.stg_breakdown WHERE full_date IS NOT NULL
    UNION -- UNION automatically drops the duplicates
    SELECT full_date FROM silver_layer.stg_status WHERE full_date IS NOT NULL
) d;

-- Nonclustered Index so it can be faster for the joins
-- I use the full_date for the joins in all fact tables
CREATE UNIQUE NONCLUSTERED INDEX ux_dim_date_dev_full_date 
ON silver_layer.dim_date_dev(full_date)
GO


/*
==============================================================
            2.SILVER LAYER WORK STATIONS DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_work_stations_dev;
CREATE TABLE silver_layer.dim_work_stations_dev (
    work_station_id       INT IDENTITY(1,1) PRIMARY KEY,
    work_station          VARCHAR(50) NOT NULL,
    equipment             VARCHAR(50) NOT NULL,
    met_date_created      DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);
GO

-- Populating dim_work_stations_dev table
INSERT INTO silver_layer.dim_work_stations_dev(work_station, equipment)
SELECT DISTINCT work_station, equipment
FROM silver_layer.stg_breakdown b;

CREATE UNIQUE NONCLUSTERED INDEX ux_dim_work_stations_dev_work_station
ON silver_layer.dim_work_stations_dev(work_station, equipment)
GO
/*
==============================================================
            3.SILVER LAYER FAILURES DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_failures_dev;
CREATE TABLE silver_layer.dim_failures_dev (
    failure_id           INT IDENTITY(1,1) PRIMARY KEY,
    failure_type         VARCHAR(50) NOT NULL,
    sub_code             VARCHAR(50) NOT NULL,
    met_date_created     DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);
GO

-- Populating dim_failures_dev table
INSERT INTO silver_layer.dim_failures_dev (failure_type, sub_code)
SELECT DISTINCT failure_type, sub_code
FROM silver_layer.stg_breakdown;

CREATE UNIQUE NONCLUSTERED INDEX ux_dim_failures_dev_failure_type
    ON silver_layer.dim_failures_dev (failure_type, sub_code);
GO

/*
==============================================================
            4.SILVER LAYER PRODUCT DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_product_dev;
CREATE TABLE silver_layer.dim_product_dev (
    product_id         INT IDENTITY(1,1) PRIMARY KEY,
    full_line          VARCHAR(100) NOT NULL, 
    version            VARCHAR(10)  NULL,
    manufacturer       VARCHAR(50)  NULL,
    model              VARCHAR(50)  NULL,
    product            VARCHAR(50)  NULL,
    met_date_created   DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);
GO

/*
---------------------------------------------------------------------------------------------
Cleaning the line variable
Ex.: D BMW M550i A-PILLAR
    1. The argument before the first space is the version of the product (D)
    2. the next argument after the first space is the manufacturer (BMW)
    3. the next argument after the second space is the version (M550i)
        3.1 In some cases the version can contain more than 1 string (Ex.: 420d Gran Coupé)
    4. The last argument is the product 

Case with only a single name model:
original:  D BMW M550i A-PILLAR
reversed:  RALLIP-A i055M WMB D

Case with multiple names model:
original:  F BMW 420d Gran Coupé B-PILLAR
reversed:  RALLIP-B épouC narG d024 WMB F
---------------------------------------------------------------------------------------------
*/

/*
---------------------------------------------------------------------------------------------
                                        CTE DEPLOYMENT

I have no Idea how can I do this properly in SQL
Created first a CTE using CASE WHEN to separate the product
Then I use a CTE to separate the manufacturer and model from the main string
*/

-- Asingle column with all the lines
WITH all_lines AS (
    SELECT full_line AS line FROM silver_layer.stg_breakdown
    WHERE full_line IS NOT NULL
    UNION
    SELECT full_line AS line FROM silver_layer.stg_status
    WHERE full_line IS NOT NULL
),

-- The convertion part
line_product AS (
    SELECT
        al.line,
        CASE
            -- Check if there is a better way to do this...
            WHEN al.line LIKE '%FRONT AXLE'       THEN 'FRONT AXLE'
            WHEN al.line LIKE '%REAR AXLE'        THEN 'REAR AXLE'
            WHEN al.line LIKE '%FRONT BUMPER'     THEN 'FRONT BUMPER'
            WHEN al.line LIKE '%FRONT BUMP'       THEN 'FRONT BUMP'
            WHEN al.line LIKE '%REAR BUMPER'      THEN 'REAR BUMPER'
            WHEN al.line LIKE '%REAR BUMP'        THEN 'REAR BUMP'
            WHEN al.line LIKE '%INSTRUMENT PANEL' THEN 'INSTRUMENT PANEL'
            WHEN al.line LIKE '%INST PANEL'       THEN 'INST PANEL'
            WHEN al.line LIKE '%A-PILLAR'         THEN 'A-PILLAR'
            WHEN al.line LIKE '%B-PILLAR'         THEN 'B-PILLAR'
            WHEN al.line LIKE '%C-PILLAR'         THEN 'C-PILLAR'
        END AS product
    FROM all_lines al
),


parsed AS (
    SELECT
        lp.line,
        lp.product,
        TRIM(
            SUBSTRING(
                lp.line,
                CHARINDEX(' ', lp.line) + 1,
                LEN(lp.line) - CHARINDEX(' ', lp.line) - LEN(lp.product)
            )
        ) AS mfr_and_model
    FROM line_product lp
    WHERE lp.product IS NOT NULL   -- drop lines that matched no CASE branch
)

-- Populating dim_product_dev table
INSERT INTO silver_layer.dim_product_dev (full_line, version, manufacturer, model, product)
SELECT
    p.line,
    TRIM(LEFT(p.line, CHARINDEX(' ', p.line) - 1)) AS version,
    TRIM(LEFT(p.mfr_and_model, CHARINDEX(' ', p.mfr_and_model) - 1)) AS manufacturer,
    SUBSTRING(
        p.mfr_and_model,
        CHARINDEX(' ', p.mfr_and_model) + 1,
        LEN(p.mfr_and_model) - CHARINDEX(' ', p.mfr_and_model)
    ) AS model,
    p.product
FROM parsed p;

CREATE UNIQUE NONCLUSTERED INDEX ux_dim_product_full_line
    ON silver_layer.dim_product_dev (full_line);
GO

/*
==============================================================
            5.SILVER LAYER TEAM LEADER STATUS DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_team_leaders_status_dev;
CREATE TABLE silver_layer.dim_team_leaders_status_dev (
    team_leader_status_id   INT IDENTITY(1,1) PRIMARY KEY,
    shift                   VARCHAR(10) NOT NULL,
    team_leader             VARCHAR(30) NOT NULL,
    num_operators           INT NOT NULL,
    all_time                INT NOT NULL,
    met_date_created        DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);
GO

-- Populating dim_team_leaders_status_dev table
INSERT INTO silver_layer.dim_team_leaders_status_dev (shift, team_leader, num_operators, all_time)
SELECT DISTINCT shift,team_leader,num_operators,all_time
FROM silver_layer.stg_status
WHERE shift IS NOT NULL
  AND team_leader IS NOT NULL
  AND num_operators IS NOT NULL;

CREATE UNIQUE NONCLUSTERED INDEX ux_dim_tls_natkey
    ON silver_layer.dim_team_leaders_status_dev (team_leader, shift, num_operators);
GO

/*
==============================================================
            6.SILVER LAYER PRODUCT DETAILS DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_product_details_dev;
CREATE TABLE silver_layer.dim_product_details_dev (
    product_details_id    INT IDENTITY(1,1) PRIMARY KEY,
    version               VARCHAR(25) NOT NULL,
    cycle_time            DECIMAL(5,2) NOT NULL,
    met_date_created      DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);
GO

-- Populating dim_product_details_dev table
INSERT INTO silver_layer.dim_product_details_dev (version, cycle_time)
SELECT DISTINCT version, cycle_time
FROM silver_layer.stg_status
WHERE version IS NOT NULL
    AND cycle_time IS NOT NULL;

CREATE UNIQUE NONCLUSTERED INDEX ux_dim_pd_natkey
    ON silver_layer.dim_product_details_dev (version, cycle_time);
GO

/*
==============================================================
            7.SILVER LAYER BREAKDOWN FACT TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.fact_breakdown_table_dev;
SELECT
    s.source_id,
    dt.date_id,
    p.product_id,
    ws.work_station_id,
    f.failure_id,
    s.event_time,
    s.unplanned_downtime,
    s.planned_downtime,
    s.failure_description,
    CAST(SYSDATETIME() AS DATETIME2) AS met_date_created
INTO silver_layer.fact_breakdown_table_dev
FROM silver_layer.stg_breakdown s
JOIN silver_layer.dim_date_dev dt 
    ON dt.full_date = s.full_date
JOIN silver_layer.dim_work_stations_dev ws 
    ON ws.work_station = s.work_station
    AND ws.equipment = s.equipment
JOIN silver_layer.dim_failures_dev f 
    ON f.failure_type = s.failure_type
    AND f.sub_code = s.sub_code
JOIN silver_layer.dim_product_dev p 
    ON p.full_line = s.full_line;
GO

-- Keys AFTER the load: clustered index FIRST, then the nonclustered PK
-- (otherwise the PK would be rebuilt when the clustered index is added).
ALTER TABLE silver_layer.fact_breakdown_table_dev
    ALTER COLUMN source_id VARCHAR(250) NOT NULL;
 
CREATE CLUSTERED INDEX cx_fact_breakdown_date
    ON silver_layer.fact_breakdown_table_dev (date_id);
 
ALTER TABLE silver_layer.fact_breakdown_table_dev
    ADD CONSTRAINT pk_fact_breakdown_dev PRIMARY KEY NONCLUSTERED (source_id);
 
ALTER TABLE silver_layer.fact_breakdown_table_dev
    ADD CONSTRAINT df_fact_breakdown_metdate DEFAULT GETDATE() FOR met_date_created;
GO

/*
==============================================================
            8.SILVER LAYER STATUS FACT TABLE
==============================================================
*/

DROP TABLE IF EXISTS silver_layer.fact_status_table_dev;
SELECT
    s.source_id,
    dt.date_id,
    p.product_id,
    tl.team_leader_status_id,
    pd.product_details_id,
    s.total_expected_output,
    s.total_produced,
    s.nok_parts,
    s.reworked_parts,
    s.accidents,
    s.near_accidents,
    s.customer_complaints,
    tl.all_time,
    s.observations,
    CAST(SYSDATETIME() AS DATETIME2) AS met_date_created
INTO silver_layer.fact_status_table_dev
FROM silver_layer.stg_status s
JOIN silver_layer.dim_date_dev dt 
    ON dt.full_date = s.full_date
JOIN silver_layer.dim_product_dev p 
    ON p.full_line = s.full_line
JOIN silver_layer.dim_team_leaders_status_dev tl 
    ON tl.team_leader = s.team_leader
    AND tl.shift = s.shift
    AND tl.num_operators = s.num_operators
JOIN silver_layer.dim_product_details_dev pd 
    ON pd.version = s.version
    AND pd.cycle_time = s.cycle_time;

GO
 
ALTER TABLE silver_layer.fact_status_table_dev
    ALTER COLUMN source_id VARCHAR(250) NOT NULL;
 
CREATE CLUSTERED INDEX cx_fact_status_date
    ON silver_layer.fact_status_table_dev (date_id);
 
ALTER TABLE silver_layer.fact_status_table_dev
    ADD CONSTRAINT pk_fact_status_dev PRIMARY KEY NONCLUSTERED (source_id);
 
ALTER TABLE silver_layer.fact_status_table_dev
    ADD CONSTRAINT df_fact_status_metdate DEFAULT GETDATE() FOR met_date_created;

GO

/*
==============================================================
            9.SILVER LAYER STATUS FACT TABLE
==============================================================
*/
DROP TABLE IF EXISTS silver_layer.stg_breakdown;
DROP TABLE IF EXISTS silver_layer.stg_status;