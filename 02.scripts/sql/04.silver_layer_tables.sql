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

OUTPUT:     Dimensions  ->  dim_work_stations_dev
                            dim_failures_dev
                            dim_product_dev
                            dim_team_leaders_status_dev
                            dim_product_details_dev
            Facts       ->  fact_breakdown_table_dev
                            fact_status_table_dev

NOTES:      - All tables carry the _dev suffix and are used for testing.
            - Script is idempotent: each table is dropped and recreated on every run.
            - The product dimension is populated from BOTH source tables (UNION)
            to guarantee no fact rows are dropped on a missing dimension key.
            - There is NO date dimension: both facts carry the calendar date itself
            (full_date). Calendar attributes (week, month, quarter, ...) come from
            the BI-side calendar table (03.scripts/powerbi/calendar_table.md).
            - The breakdown fact carries shift, shift_abc and team_leader_status_id,
            recovered from the report file name embedded in the source ID (joined back
            to the status staging), so BI can relate breakdowns to
            dim_team_leaders_status_dev.

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
    SUBSTRING(b.ID, 0, CHARINDEX('_', b.ID))           AS source_id_key,
    CONVERT(date, b.[date], 103)                       AS full_date,
    TRIM(SUBSTRING(b.ID, CHARINDEX(' ', b.ID) + 1,CHARINDEX('.', b.ID) - CHARINDEX(' ', b.ID) - 1)) AS shift_abc,
    ISNULL(NULLIF(TRIM(b.work_station), ''), 'N/A')    AS work_station,
    ISNULL(NULLIF(TRIM(b.machine),    ''), 'N/A')      AS equipment,
    ISNULL(NULLIF(TRIM(b.failure_type), ''), 'N/A')    AS failure_type,
    ISNULL(NULLIF(TRIM(b.sub_failure_type),     ''), 'N/A')    AS sub_code,
    TRIM(b.line)                                       AS full_line,
    CONVERT(TIME(0), TRIM(b.event_time))               AS event_time,
    CONVERT(INT, TRIM(SUBSTRING(b.unplanned_downtime, 0, CHARINDEX('.', b.unplanned_downtime))))     AS unplanned_downtime,
    CONVERT(INT, TRIM(SUBSTRING(b.planned_downtime, 0, CHARINDEX('.', b.planned_downtime))))         AS planned_downtime,
    REPLACE(REPLACE(REPLACE(TRIM(b.failure_description), ' ', '<>'), '><', ''), '<>', ' ')           AS failure_description
INTO silver_layer.stg_breakdown
FROM bronze_layer.breakdown_data b;
GO

/*
==============================================================
                    0.2 STAGING STATUS TABLE
==============================================================
*/

DROP TABLE IF EXISTS silver_layer.stg_status;
WITH staged AS (
    SELECT
        b.ID                                       AS source_id,
        CONVERT(date, b.[date], 103)               AS full_date,
        TRIM(b.line)                               AS full_line,
        REPLACE(TRIM(b.shift),'evening', 'night')  AS shift,
        TRIM(SUBSTRING(b.ID, CHARINDEX(' ', b.ID) + 1,CHARINDEX('.', b.ID) - CHARINDEX(' ', b.ID) - 1))    AS shift_abc,
        TRIM(b.leader)                             AS team_leader,
        CONVERT(INT, TRIM(b.num_operators))        AS num_operators,
        CASE WHEN TRIM(b.shift) = 'night' THEN 450 ELSE 480 END                                            AS all_time,
        CONVERT(INT, TRIM(b.total_produced))       AS total_produced,
        CONVERT(INT, TRIM(b.nok_parts))            AS nok_parts,
        CONVERT(INT, TRIM(b.reworked_parts))       AS reworked_parts,
        -- collapse repeated whitespaces:
        REPLACE(REPLACE(REPLACE(TRIM(b.observations), ' ', '<>'), '><', ''), '<>', ' ')                    AS observations,
        b.version,
        CONVERT(DECIMAL(5,2),NULLIF(TRIM(REPLACE(REPLACE(cycle_time, CHAR(13), ''), CHAR(10), '')), ''))   AS cycle_time
    FROM bronze_layer.status_data b
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY full_date, full_line, shift
               ORDER BY shift_abc ASC
           ) AS rn
    FROM staged
)

SELECT * INTO silver_layer.stg_status FROM ranked WHERE rn = 1;
GO


/*
==============================================================
            1.SILVER LAYER DATE DIM TABLE (REMOVED)

The date dimension was eliminated: the facts now carry
full_date directly and the calendar attributes live in the
BI-side calendar table. The DROP below only migrates a
database built by an earlier version of this script.
==============================================================
*/

DROP TABLE IF EXISTS silver_layer.dim_date_dev;
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
Ex.: V1 HAUSBERG BakePro 700 POWER BOARD
    1. The token before the first space is the version   (V1 / V2 / V3 / STAND)
    2. the next token is the manufacturer                (HAUSBERG / WEISSTECH)
    3. the middle tokens are the model, always TWO words: a name plus a size/number
       (Ex.: BakePro 700, FrostCool 550, DuraWash 500, AquaMaster 360, SpinDry 580, EcoWash 300)
    4. the last TWO words are the product                (Ex.: POWER BOARD, SIDE PANEL, DRUM UNIT)

The parse is position-based, so it copes with the two-token model automatically:
    version       = everything left of the 1st space          -> V1
    product       = matched from the fixed list of 8 products  -> POWER BOARD
    mfr_and_model = what is left between version and product    -> HAUSBERG BakePro 700
    manufacturer  = left of the 1st space of mfr_and_model      -> HAUSBERG
    model         = the remainder                               -> BakePro 700
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
            -- The 8 products in the new appliance data; each is exactly two words.
            WHEN al.line LIKE '%CONTROL PANEL' THEN 'CONTROL PANEL'
            WHEN al.line LIKE '%DISPLAY BOARD' THEN 'DISPLAY BOARD'
            WHEN al.line LIKE '%DOOR PANEL'    THEN 'DOOR PANEL'
            WHEN al.line LIKE '%DRUM UNIT'     THEN 'DRUM UNIT'
            WHEN al.line LIKE '%MAIN BOARD'    THEN 'MAIN BOARD'
            WHEN al.line LIKE '%MOTOR UNIT'    THEN 'MOTOR UNIT'
            WHEN al.line LIKE '%POWER BOARD'   THEN 'POWER BOARD'
            WHEN al.line LIKE '%SIDE PANEL'    THEN 'SIDE PANEL'
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
    shift_abc               VARCHAR(10) NOT NULL,
    team_leader             VARCHAR(30) NOT NULL,
    num_operators           INT NOT NULL,
    all_time                INT NOT NULL,
    met_date_created        DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
);
GO

-- Populating dim_team_leaders_status_dev table
INSERT INTO silver_layer.dim_team_leaders_status_dev (shift, shift_abc, team_leader, num_operators, all_time)
SELECT DISTINCT shift, shift_abc, team_leader,num_operators,all_time
FROM silver_layer.stg_status
WHERE shift IS NOT NULL
    AND shift_abc IS NOT NULL
    AND team_leader IS NOT NULL
    AND num_operators IS NOT NULL;

CREATE UNIQUE NONCLUSTERED INDEX ux_dim_tls_natkey
    ON silver_layer.dim_team_leaders_status_dev (team_leader, shift, shift_abc, num_operators);
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
    s.full_date,
    p.product_id,
    ws.work_station_id,
    f.failure_id,
    tl.team_leader_status_id,
    st.shift,
    s.shift_abc,
    s.event_time,
    s.unplanned_downtime,
    s.planned_downtime,
    s.failure_description,
    CAST(SYSDATETIME() AS DATETIME2) AS met_date_created
INTO silver_layer.fact_breakdown_table_dev
FROM silver_layer.stg_breakdown s
JOIN silver_layer.dim_work_stations_dev ws
    ON ws.work_station = s.work_station
    AND ws.equipment = s.equipment
JOIN silver_layer.dim_failures_dev f
    ON f.failure_type = s.failure_type
    AND f.sub_code = s.sub_code
JOIN silver_layer.dim_product_dev p
    ON p.full_line = s.full_line
JOIN silver_layer.stg_status st
    ON st.full_date = s.full_date
    AND st.full_line = s.full_line
    AND st.shift_abc = s.shift_abc
JOIN silver_layer.dim_team_leaders_status_dev tl
    ON tl.team_leader = st.team_leader
    AND tl.shift = st.shift
    AND tl.shift_abc = st.shift_abc
    AND tl.num_operators = st.num_operators
WHERE s.full_date IS NOT NULL;
GO

-- Keys AFTER the load: clustered index FIRST, then the nonclustered PK
-- (otherwise the PK would be rebuilt when the clustered index is added).
ALTER TABLE silver_layer.fact_breakdown_table_dev
    ALTER COLUMN source_id VARCHAR(250) NOT NULL;

ALTER TABLE silver_layer.fact_breakdown_table_dev
    ALTER COLUMN full_date DATE NOT NULL;

-- SELECT INTO infers wide varchars for the computed columns; align them with the dim types.
-- Both stay NULLable: rows without a matching status report carry NULL shift.
ALTER TABLE silver_layer.fact_breakdown_table_dev
    ALTER COLUMN shift VARCHAR(10) NULL;

ALTER TABLE silver_layer.fact_breakdown_table_dev
    ALTER COLUMN shift_abc VARCHAR(10) NULL;

CREATE CLUSTERED INDEX cx_fact_breakdown_date
    ON silver_layer.fact_breakdown_table_dev (full_date);
 
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
    s.full_date,
    p.product_id,
    tl.team_leader_status_id,
    pd.product_details_id,
    s.total_produced,
    s.nok_parts,
    s.reworked_parts,
    tl.all_time,
    s.observations,
    CAST(SYSDATETIME() AS DATETIME2) AS met_date_created
INTO silver_layer.fact_status_table_dev
FROM silver_layer.stg_status s
JOIN silver_layer.dim_product_dev p
    ON p.full_line = s.full_line
JOIN silver_layer.dim_team_leaders_status_dev tl
    ON tl.team_leader = s.team_leader
    AND tl.shift = s.shift
    AND tl.shift_abc = s.shift_abc
    AND tl.num_operators = s.num_operators
JOIN silver_layer.dim_product_details_dev pd
    ON pd.version = s.version
    AND pd.cycle_time = s.cycle_time
-- same behavior the old inner join to dim_date had: dateless rows are dropped
WHERE s.full_date IS NOT NULL;

GO

ALTER TABLE silver_layer.fact_status_table_dev
    ALTER COLUMN source_id VARCHAR(250) NOT NULL;

ALTER TABLE silver_layer.fact_status_table_dev
    ALTER COLUMN full_date DATE NOT NULL;

CREATE CLUSTERED INDEX cx_fact_status_date
    ON silver_layer.fact_status_table_dev (full_date);
 
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