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

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_work_stations_dev;
CREATE TABLE gold_layer.dim_work_stations_dev (

    work_station_id       INT PRIMARY KEY,
    work_station          VARCHAR(50) NOT NULL,
    equipment             VARCHAR(50) NULL,
    met_date_created      DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_failures_dev;
CREATE TABLE gold_layer.dim_failures_dev (
    
    failure_id           INT PRIMARY KEY,
    failure_type         VARCHAR(50) NOT NULL,
    sub_code             VARCHAR(50) NULL,
    met_date_created     DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

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

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_team_leaders_status_dev;
CREATE TABLE gold_layer.dim_team_leaders_status_dev (

    team_leader_status_id   INT PRIMARY KEY,
    shift                   VARCHAR(10) NOT NULL,
    team_leader             VARCHAR(30) NOT NULL,
    num_operators           INT NOT NULL,
    met_date_created        DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time
    
);

-- Security Layer for table existance checking
DROP TABLE IF EXISTS gold_layer.dim_product_details_dev;
CREATE TABLE gold_layer.dim_product_details_dev (

    product_details_id    INT PRIMARY KEY,
    version               VARCHAR(25) NOT NULL,
    cycle_time            DECIMAL(5,2) NOT NULL,
    met_date_created      DATETIME2 DEFAULT GETDATE() -- A metadata column to get the creation date/time

);

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
