/*
================================================================================================
                                    GOLD LAYER
================================================================================================
DATABASE:   db_manufacturing_warehouse
SCHEMA:     gold_layer
------------------------------------------------------------------------------------------------
PURPOSE:    Reads the cleaned star schema from the silver_layer and materializes the
            business-ready presentation layer. Facts are enriched with the calculated OEE
            metrics (availability, performance, quality, OEE) and supporting figures so the
            data is ready for direct consumption by BI tools and reporting.

OUTPUT:     Dimensions   ->  dim_date_dev
                             dim_work_stations_dev
                             dim_failures_dev
                             dim_product_dev
                             dim_team_leaders_status_dev
                             dim_product_details_dev
            Facts        ->  fact_breakdown_table_dev
                             fact_status_table_dev   (enriched with OEE metrics)
            Constraints  ->  Foreign keys linking each fact to its dimensions (gold -> gold only)

NOTES:      - All tables carry the _dev suffix and are used for testing.
            - Script is idempotent: each table is dropped and recreated on every run.
            - Both fact tables are dropped first, since a dimension cannot be dropped while a
            foreign key from a fact still references it.
            - Foreign keys are declared INLINE in each fact's CREATE TABLE, so the dimensions
            are created BEFORE the facts (the breakdown fact is created after the dimensions
            for this reason).
            - Dimensions must be populated before the facts, or the foreign keys will reject
            the fact rows.

------------------------------------------------------------------------------------------------
AUTHOR:     Eduardo Cysne
STARTED:    06/06/2026
================================================================================================
*/

-- Security Layer for table existance checking
-- Facts are dropped first: a dimension cannot be dropped while a FK from a fact still references it.
DROP TABLE IF EXISTS gold_layer.fact_status_table_dev;
DROP TABLE IF EXISTS gold_layer.fact_breakdown_table_dev;

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_date_dev;
CREATE TABLE gold_layer.dim_date_dev (

    date_id            INT PRIMARY KEY,
    full_date          DATE NOT NULL,
    day_num            INT NOT NULL,
    day_name           VARCHAR(50) NOT NULL,
    week_num           INT NOT NULL,
    month_num          INT NOT NULL,
    month_name         VARCHAR(50) NOT NULL,
    year_num           INT NOT NULL,
    met_date_created   DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

INSERT INTO gold_layer.dim_date_dev(date_id,full_date, day_num, day_name, week_num, month_num, month_name, year_num)
SELECT
    d.date_id,
    d.full_date,
    d.day_num,
    d.day_name,
    d.week_num,
    d.month_num,
    d.month_name,
    d.year_num
FROM silver_layer.dim_date_dev d;


-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_work_stations_dev;
CREATE TABLE gold_layer.dim_work_stations_dev (

    work_station_id       INT PRIMARY KEY,
    work_station          VARCHAR(50) NOT NULL,
    equipment             VARCHAR(50) NULL,
    met_date_created      DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

INSERT INTO gold_layer.dim_work_stations_dev(work_station_id, work_station, equipment)
SELECT
    d.work_station_id,
    d.work_station,
    d.equipment
FROM silver_layer.dim_work_stations_dev d;

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_failures_dev;
CREATE TABLE gold_layer.dim_failures_dev (
    
    failure_id           INT PRIMARY KEY,
    failure_type         VARCHAR(50) NOT NULL,
    sub_code             VARCHAR(50) NULL,
    met_date_created     DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

INSERT INTO gold_layer.dim_failures_dev(failure_id, failure_type, sub_code)
SELECT
    d.failure_id,
    d.failure_type,
    d.sub_code
FROM silver_layer.dim_failures_dev d;

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_product_dev;
CREATE TABLE gold_layer.dim_product_dev (

    product_id         INT PRIMARY KEY,
    full_line          VARCHAR(100) NOT NULL, 
    version            VARCHAR(10)  NULL,
    manufacturer       VARCHAR(50)  NULL,
    model              VARCHAR(50)  NULL,
    product            VARCHAR(50)  NULL,
    met_date_created   DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

INSERT INTO gold_layer.dim_product_dev(product_id, full_line, version, manufacturer, model, product)
SELECT
    d.product_id,
    d.full_line,
    d.version,
    d.manufacturer,
    d.model,
    d.product
FROM silver_layer.dim_product_dev d;

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_team_leaders_status_dev;
CREATE TABLE gold_layer.dim_team_leaders_status_dev (

    team_leader_status_id   INT PRIMARY KEY,
    shift                   VARCHAR(10) NOT NULL,
    team_leader             VARCHAR(30) NOT NULL,
    num_operators           INT NOT NULL,
    met_date_created        DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
    
);

INSERT INTO gold_layer.dim_team_leaders_status_dev(team_leader_status_id, shift, team_leader, num_operators)
SELECT
    d.team_leader_status_id,
    d.shift,
    d.team_leader,
    d.num_operators
FROM silver_layer.dim_team_leaders_status_dev d;

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_product_details_dev;
CREATE TABLE gold_layer.dim_product_details_dev (

    product_details_id    INT PRIMARY KEY,
    version               VARCHAR(25) NOT NULL,
    cycle_time            DECIMAL(5,2) NOT NULL,
    met_date_created      DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

INSERT INTO gold_layer.dim_product_details_dev(product_details_id, version, cycle_time)
SELECT
    d.product_details_id,
    d.version,
    d.cycle_time
FROM silver_layer.dim_product_details_dev d;

-- Security Layer for table existance checking
-- fact_breakdown_table_dev is dropped at the top of the script (before the dimensions),
-- and created here AFTER the dimensions so its inline foreign keys can resolve.
CREATE TABLE gold_layer.fact_breakdown_table_dev (

    source_id            VARCHAR(250) PRIMARY KEY,
    date_id              INT NOT NULL,
    product_id           INT NOT NULL,
    work_station_id      INT NOT NULL,
    failure_id           INT NOT NULL,
    event_time           TIME(0) NOT NULL,
    unplanned_downtime   INT NULL,
    planned_downtime     INT NULL,
    failure_description  VARCHAR(MAX) NULL,
    met_date_created     DATETIME2 DEFAULT GETDATE(), -- A metadata column to get the creation date/time

    CONSTRAINT FK_fact_breakdown_date FOREIGN KEY (date_id) REFERENCES gold_layer.dim_date_dev (date_id),
    CONSTRAINT FK_fact_breakdown_product FOREIGN KEY (product_id) REFERENCES gold_layer.dim_product_dev (product_id),
    CONSTRAINT FK_fact_breakdown_workstation FOREIGN KEY (work_station_id) REFERENCES gold_layer.dim_work_stations_dev (work_station_id),
    CONSTRAINT FK_fact_breakdown_failure FOREIGN KEY (failure_id) REFERENCES gold_layer.dim_failures_dev (failure_id)

);

INSERT INTO gold_layer.fact_breakdown_table_dev(
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

SELECT
    f.source_id,
    f.date_id,
    f.product_id,
    f.work_station_id,
    f.failure_id,
    f.event_time,
    f.unplanned_downtime,
    f.planned_downtime,
    f.failure_description
FROM silver_layer.fact_breakdown_table_dev f;


-- Security Layer for table existance checking
-- fact_status_table_dev is dropped at the top of the script (before the dimensions).
CREATE TABLE gold_layer.fact_status_table_dev (

    source_id                VARCHAR(250) PRIMARY KEY,
    date_id                  INT NOT NULL,
    product_id               INT NOT NULL,
    team_leader_status_id    INT NOT NULL,
    product_details_id       INT NOT NULL,
    total_expected_output    INT NULL,
    total_produced           INT NULL,
    nok_parts                INT NULL,
    reworked_parts           INT NULL,
    accidents                INT NULL,
    near_accidents           INT NULL,
    customer_complaints      INT NULL,
    all_time                 INT NULL,
    observations             VARCHAR(MAX) NULL,
    ok_parts                 INT NULL,
    quality                  DECIMAL(5,1) NULL,
    planned_production_time  INT NULL,
    availability_loss        INT NULL,
    run_time                 INT NULL,
    performance              DECIMAL(5,1) NULL,
    availability             DECIMAL(5,1) NULL,
    fully_productive_time    INT NULL,
    pplh                     DECIMAL(5,1) NULL,
    ok_first_parts           INT NULL,
    ftq                      DECIMAL(5,1) NULL,
    oee                      DECIMAL(5,1) NULL,
    met_date_created         DATETIME2 DEFAULT GETDATE(), -- A metadata column to get the creation date/time

    CONSTRAINT FK_fact_status_date FOREIGN KEY (date_id) REFERENCES gold_layer.dim_date_dev (date_id),
    CONSTRAINT FK_fact_status_product FOREIGN KEY (product_id) REFERENCES gold_layer.dim_product_dev (product_id),
    CONSTRAINT FK_fact_status_teamleader FOREIGN KEY (team_leader_status_id) REFERENCES gold_layer.dim_team_leaders_status_dev (team_leader_status_id),
    CONSTRAINT FK_fact_status_productdetails FOREIGN KEY (product_details_id) REFERENCES gold_layer.dim_product_details_dev (product_details_id)

);

WITH breakdown_downtime AS (
    -- Roll downtime up to date + product + shift. The breakdown fact has no shift key,
    -- so the shift is derived from event_time using fixed windows (convention, not sourced):
    -- morning 06:00-14:00, afternoon 14:00-22:00, evening 22:00-06:00 (wraps midnight)
    SELECT
        bf.date_id,
        bf.product_id,
        CASE
            WHEN bf.event_time >= '06:00:00' AND bf.event_time < '14:00:00' THEN 'morning'
            WHEN bf.event_time >= '14:00:00' AND bf.event_time < '22:00:00' THEN 'afternoon'
            ELSE 'evening'   -- 22:00:00-05:59:59
        END                                   AS shift,
        SUM(ISNULL(bf.unplanned_downtime, 0)) AS total_unplanned_downtime,
        SUM(ISNULL(bf.planned_downtime, 0))   AS total_planned_downtime
    FROM silver_layer.fact_breakdown_table_dev bf
    GROUP BY
        bf.date_id,
        bf.product_id,
        CASE
            WHEN bf.event_time >= '06:00:00' AND bf.event_time < '14:00:00' THEN 'morning'
            WHEN bf.event_time >= '14:00:00' AND bf.event_time < '22:00:00' THEN 'afternoon'
            ELSE 'evening'
        END
),

base AS (
    SELECT
        s.source_id,
        s.date_id,
        s.product_id,
        s.team_leader_status_id,
        s.product_details_id,
        s.total_expected_output,
        s.total_produced,
        s.nok_parts,
        s.reworked_parts,
        s.accidents,
        s.near_accidents,
        s.customer_complaints,
        s.all_time,
        s.observations,
        pd.cycle_time,
        ISNULL(bd.total_unplanned_downtime, 0) AS unplanned_downtime,
        ISNULL(bd.total_planned_downtime, 0)   AS planned_downtime
    FROM silver_layer.fact_status_table_dev s
    JOIN silver_layer.dim_product_details_dev pd
        ON pd.product_details_id = s.product_details_id
    -- tl carries the status row's shift, which keys the downtime match below.
    JOIN silver_layer.dim_team_leaders_status_dev tl
        ON tl.team_leader_status_id = s.team_leader_status_id
    LEFT JOIN breakdown_downtime bd
        ON bd.date_id    = s.date_id
        AND bd.product_id = s.product_id
        AND bd.shift      = tl.shift
),

-- Intermediate figures the OEE ratios build on (kept separate so each ratio reads cleanly).
calc AS (
    SELECT
        base.*,
        (total_produced - nok_parts)                             AS ok_parts,
        unplanned_downtime                                       AS availability_loss,
        (all_time - planned_downtime)                            AS planned_production_time,
        (all_time - planned_downtime - unplanned_downtime)       AS run_time,
        (all_time - unplanned_downtime - planned_downtime)       AS fully_productive_time
    FROM base
),

-- The three OEE ratios; OEE itself is their product.
metrics AS (
    SELECT
        calc.*,
        CAST(ok_parts AS DECIMAL(6,2)) / NULLIF(total_produced, 0)                 AS quality,
        (CAST(total_produced AS DECIMAL(6,2)) * cycle_time) / NULLIF(run_time, 0)  AS performance,
        CAST(run_time AS DECIMAL(6,2)) / NULLIF(planned_production_time, 0)        AS availability
    FROM calc
)

INSERT INTO gold_layer.fact_status_table_dev (
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
    all_time,
    observations,
    ok_parts,
    quality,
    planned_production_time,
    availability_loss,
    run_time,
    performance,
    availability,
    fully_productive_time,
    pplh,
    ok_first_parts,
    ftq,
    oee
)
    SELECT
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
        all_time,
        observations,
        ok_parts,
        quality,
        planned_production_time,
        availability_loss,
        run_time,
        performance,
        availability,
        fully_productive_time,
        CAST(total_produced AS DECIMAL(6,2)) / NULLIF(fully_productive_time, 0)      AS pplh,
        (ok_parts - reworked_parts)                                                  AS ok_first_parts,
        CAST(ok_parts - reworked_parts AS DECIMAL(6,2)) / NULLIF(total_produced, 0)  AS ftq,
        (availability * performance * quality)                                       AS oee
    FROM metrics;