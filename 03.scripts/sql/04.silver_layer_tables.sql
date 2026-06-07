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
            Facts       ->  fact_breakdown_table
                            fact_status_table

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
                SILVER LAYER DATE DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_date_dev;
CREATE TABLE silver_layer.dim_date_dev (
    -- IDENTITY(1,1) makes the table autogenerate data starting from 1 and incrementing by 1
    date_id            INT IDENTITY(1,1) PRIMARY KEY,
    full_date          DATE NOT NULL,
    day_num            INT NOT NULL,
    day_name           VARCHAR(50) NOT NULL,
    week_num           INT NOT NULL,
    month_num          INT NOT NULL,
    month_name         VARCHAR(50) NOT NULL,
    year_num           INT NOT NULL,
    met_date_created   DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);

-- Populating dim_date_dev table
INSERT INTO silver_layer.dim_date_dev(full_date, day_num, day_name, week_num, month_num, month_name, year_num)
SELECT
    d.full_date,
    DATEPART(day, d.full_date),
    DATENAME(weekday, d.full_date),
    DATEPART(ISO_WEEK, d.full_date),
    DATEPART(month, d.full_date),
    DATENAME(month, d.full_date),
    DATEPART(year, d.full_date)
FROM (
    SELECT DISTINCT CONVERT(date, b.[date], 103) AS full_date
    FROM bronze_layer.wel_breakdown_data b
    WHERE b.[date] IS NOT NULL

    UNION  -- de-dupes across both

    SELECT DISTINCT CONVERT(date, s.[date], 103) AS full_date
    FROM bronze_layer.wel_status_data s
    WHERE s.[date] IS NOT NULL
) d;

/*
==============================================================
            SILVER LAYER WORK STATIONS DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_work_stations_dev;
CREATE TABLE silver_layer.dim_work_stations_dev (
    work_station_id       INT IDENTITY(1,1) PRIMARY KEY,
    work_station          VARCHAR(50) NOT NULL,
    equipment             VARCHAR(50)  NULL,
    met_date_created      DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);

-- Populating dim_work_stations_dev table
INSERT INTO silver_layer.dim_work_stations_dev(work_station, equipment)
    SELECT DISTINCT
        TRIM(b.work_station),
        TRIM(b.equipment)
    FROM bronze_layer.wel_breakdown_data b
    WHERE b.[work_station] IS NOT NULL;

-- Handle NULL Values
INSERT INTO silver_layer.dim_work_stations_dev(work_station, equipment)
VALUES('N/A', 'N/A');

/*
==============================================================
            SILVER LAYER FAILURES DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_failures_dev;
CREATE TABLE silver_layer.dim_failures_dev (
    
    failure_id           INT IDENTITY(1,1) PRIMARY KEY,
    failure_type         VARCHAR(50) NOT NULL,
    sub_code             VARCHAR(50) NULL,
    met_date_created     DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

-- Populating dim_failures_dev table
INSERT INTO silver_layer.dim_failures_dev (failure_type, sub_code)
    SELECT DISTINCT
        TRIM(b.failure_type),
        TRIM(b.sub_code)
    FROM bronze_layer.wel_breakdown_data b
    WHERE b.[failure_type] IS NOT NULL;

-- Handle NULL Values
INSERT INTO silver_layer.dim_failures_dev (failure_type, sub_code)
VALUES('N/A', 'N/A');

/*
==============================================================
            SILVER LAYER PRODUCT DIM TABLE
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

WITH all_lines AS (
    SELECT DISTINCT TRIM(line) AS line
    FROM bronze_layer.wel_breakdown_data
    WHERE line IS NOT NULL

    UNION   -- UNION (not UNION ALL) de-dupes across both tables

    SELECT DISTINCT TRIM(line) AS line
    FROM bronze_layer.wel_status_data
    WHERE line IS NOT NULL
),

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

/*
==============================================================
            SILVER LAYER BREAKDOWN FACT TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.fact_breakdown_table;
CREATE TABLE silver_layer.fact_breakdown_table (
    source_id            VARCHAR(250) PRIMARY KEY,
    date_id              INT NOT NULL,
    product_id           INT NOT NULL,
    work_station_id      INT NOT NULL,
    failure_id           INT NOT NULL,
    event_time           TIME(0) NOT NULL,
    unplanned_downtime   INT NULL,
    planned_downtime     INT NULL,
    failure_description  NVARCHAR(MAX),
    met_date_created     DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

-- Populating fact_breakdown_table table
INSERT INTO silver_layer.fact_breakdown_table (
    source_id, 
    date_id, 
    product_id, 
    work_station_id, 
    failure_id,
    event_time,
    unplanned_downtime,
    planned_downtime,
    failure_description
)
    SELECT DISTINCT 
        b.ID,
        dt.date_id,
        p.product_id,
        ws.work_station_id,
        f.failure_id,
        b.event_time,
        b.unplanned_downtime,
        b.planned_downtime,
        b.failure_description
    FROM bronze_layer.wel_breakdown_data b 
    JOIN silver_layer.dim_date_dev dt 
        ON dt.full_date = CONVERT(date, b.[date], 103)
    JOIN silver_layer.dim_work_stations_dev ws
        ON ISNULL(NULLIF(ws.work_station,''),'N/A') = ISNULL(NULLIF(TRIM(b.work_station),''),'N/A')
        AND ISNULL(NULLIF(ws.equipment, ''),'N/A') = ISNULL(NULLIF(TRIM(b.equipment), ''),'N/A')
    JOIN silver_layer.dim_failures_dev f 
        ON ISNULL(NULLIF(f.failure_type,''), 'N/A') = ISNULL(NULLIF(TRIM(b.failure_type),''),'N/A')
        AND ISNULL(NULLIF(f.sub_code, ''),'N/A') = ISNULL(NULLIF(TRIM(b.sub_code), ''),'N/A')
    JOIN silver_layer.dim_product_dev p
        ON p.full_line = TRIM(b.line);

/*
==============================================================
            SILVER LAYER TEAM LEADER STATUS DIM TABLE
==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.dim_team_leaders_status_dev;
CREATE TABLE silver_layer.dim_team_leaders_status_dev (
    team_leader_status_id   INT IDENTITY(1,1) PRIMARY KEY,
    shift                   VARCHAR(10) NOT NULL,
    team_leader             VARCHAR(30) NOT NULL,
    num_operators           INT NOT NULL,
    met_date_created        DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);

-- Populating dim_team_leaders_status_dev table
INSERT INTO silver_layer.dim_team_leaders_status_dev (shift, team_leader, num_operators)
    SELECT DISTINCT
        TRIM(b.shift),
        TRIM(b.team_leader),
        b.num_operators
    FROM bronze_layer.wel_status_data b
    WHERE b.shift IS NOT NULL
        AND b.team_leader IS NOT NULL
        AND b.num_operators IS NOT NULL;

/*
==============================================================================================================
                                            SILVER LAYER DAY STATUS DIM TABLE

Observation problem solution:
Observation: "my     name is eduardo         and I love    dogs  a lot"
    1. REPLACE(text, ' ', '<>'): my<><><><><>name<>is<>eduardo<><><><><><><><><>and<>I<>love<><><><>dogs<><>a<>lot
    2. REPLACE(..., '><', ''): my<>name<>is<>eduardo<>and<>I<>love<>dogs<>a<>lot
    3. REPLACE(..., '<>', ' '): my name is eduardo and I love dogs a lot
=============================================================================================================
*/

/*
==============================================================
            SILVER LAYER PRODUCT DETAILS DIM TABLE
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

-- Populating dim_product_details_dev table
INSERT INTO silver_layer.dim_product_details_dev (version, cycle_time)
    SELECT DISTINCT
        b.version,
        b.cycle_time
    FROM bronze_layer.wel_status_data b
    WHERE b.version IS NOT NULL
        AND b.cycle_time IS NOT NULL;

/*
==============================================================
            SILVER LAYER STATUS FACT TABLE

CREATE TABLE bronze_layer.wel_status_data (

    ID                          VARCHAR(250) PRIMARY KEY,
    date                        DATE,
    line                        VARCHAR(100), 
    shift                       VARCHAR(10),
    team_leader                 VARCHAR(30),
    num_operators               INT,
    total_expected_output       INT,
    total_produced              INT,
    nok_parts                   INT,
    reworked_parts              INT,
    accidents                   INT,
    near_accidents              INT,
    customer_complaints         INT,
    observations                NVARCHAR(MAX),
    version                     VARCHAR(25),
    cycle_time                  DECIMAL(5,2)

);

==============================================================
*/

-- Security Layer for table existance checking
DROP TABLE IF EXISTS silver_layer.fact_status_table;
CREATE TABLE silver_layer.fact_status_table (
    source_id               VARCHAR(250) PRIMARY KEY,
    date_id                 INT NOT NULL,
    product_id              INT NOT NULL,
    team_leader_status_id   INT NOT NULL,
    product_details_id      INT NOT NULL,
    total_expected_output   INT NULL,
    total_produced          INT NULL,
    nok_parts               INT NULL,
    reworked_parts          INT NULL,
    accidents               INT NULL,
    near_accidents          INT NULL,
    customer_complaints     INT NULL,
    observations            NVARCHAR(MAX) NULL,
    met_date_created        DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);

-- Populating fact_status_table table
INSERT INTO silver_layer.fact_status_table (
    source_id,
    date_id,
    product_id,
    team_leader_status_id,
    product_details_id,
    total_expected_output,
    total_produced,
    nok_parts,
    reworked_parts,
    accidents,
    near_accidents,
    customer_complaints,
    observations
)

/*
Observation: "my     name is eduardo         and I love    dogs  a lot"
    1. REPLACE(text, ' ', '<>'): my<><><><><>name<>is<>eduardo<><><><><><><><><>and<>I<>love<><><><>dogs<><>a<>lot
    2. REPLACE(..., '><', ''): my<>name<>is<>eduardo<>and<>I<>love<>dogs<>a<>lot
    3. REPLACE(..., '<>', ' '): my name is eduardo and I love dogs a lot
*/

    SELECT DISTINCT
        b.ID,
        dt.date_id,
        p.product_id,
        tl.team_leader_status_id,
        pd.product_details_id,
        b.total_expected_output,
        b.total_produced,
        b.nok_parts,
        b.reworked_parts,
        b.accidents,
        b.near_accidents,
        b.customer_complaints,
        REPLACE(REPLACE(REPLACE(TRIM(b.observations), ' ', '<>'), '><', ''), '<>', ' ') AS observations
    FROM bronze_layer.wel_status_data b
    JOIN silver_layer.dim_date_dev dt
        ON dt.full_date = CONVERT(date, b.[date], 103)
    JOIN silver_layer.dim_product_dev p
        ON p.full_line = TRIM(b.line)
    JOIN silver_layer.dim_team_leaders_status_dev tl
        ON tl.team_leader = TRIM(b.team_leader)
        AND tl.shift = TRIM(b.shift)
        AND tl.num_operators = b.num_operators
    JOIN silver_layer.dim_product_details_dev pd
        ON ISNULL(pd.version,'') = ISNULL(b.version,'') -- NULL != NULL, but '' = ''
        AND pd.cycle_time = b.cycle_time;