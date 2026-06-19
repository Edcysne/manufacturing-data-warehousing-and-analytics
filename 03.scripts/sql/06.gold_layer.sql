/*
================================================================================================
                                    GOLD LAYER
================================================================================================
DATABASE:   db_manufacturing_warehouse
SCHEMA:     gold_layer
------------------------------------------------------------------------------------------------
PURPOSE:    Exposes the cleaned star schema from the silver_layer as a business-ready
            presentation layer of VIEWS. The status fact is enriched on read with the
            calculated OEE metrics (availability, performance, quality, OEE) and supporting
            figures, so the data is ready for direct consumption by BI tools and reporting.

OUTPUT:     Dimensions   ->  dim_date_dev
                             dim_work_stations_dev
                             dim_failures_dev
                             dim_product_dev
                             dim_team_leaders_status_dev
                             dim_product_details_dev
            Facts        ->  fact_breakdown_table_dev
                             fact_status_table_dev   (enriched with OEE metrics)

NOTES:      - The gold layer is implemented as VIEWS over the silver_layer. It stores no data
            and always reflects the current silver_layer state (no refresh step, no drift).
            - Because they are views, gold objects carry NO primary or foreign keys; referential
            integrity is enforced upstream in the silver_layer.
            - The metadata column met_date_created is intentionally dropped: a per-row creation
            timestamp is meaningless in a view (it would evaluate to the query time).
            - Script is idempotent: it drops any existing table OR view of the same name before
            (re)creating the view, so it also migrates a previous table-based gold layer.
            - T-SQL requires CREATE VIEW to be the first statement in a batch, hence the GO
            separators throughout this script.
            - If a specific view later becomes a performance bottleneck, materialize just that
            one (a table with a refresh step, or an indexed view).

------------------------------------------------------------------------------------------------
AUTHOR:     Eduardo Cysne
STARTED:    06/06/2026
================================================================================================
*/

/*
==============================================================
            CLEANUP (tables or views, any prior run)

Facts are dropped first: in the previous table-based version a
dimension could not be dropped while a FK from a fact still
referenced it. Harmless for views, kept for safe migration.
==============================================================
*/

DROP VIEW  IF EXISTS gold_layer.fact_status_enriched_dev;
DROP VIEW  IF EXISTS gold_layer.fact_breakdown_table_dev;

DROP VIEW  IF EXISTS gold_layer.dim_date_dev;
DROP VIEW  IF EXISTS gold_layer.dim_work_stations_dev;
DROP VIEW  IF EXISTS gold_layer.dim_failures_dev;
DROP VIEW  IF EXISTS gold_layer.dim_product_dev;
DROP VIEW  IF EXISTS gold_layer.dim_team_leaders_status_dev;
DROP VIEW  IF EXISTS gold_layer.dim_product_details_dev;
GO

/*
==============================================================
                GOLD LAYER DATE DIM VIEW
==============================================================
*/

CREATE VIEW gold_layer.dim_date_dev AS
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
GO

/*
==============================================================
            GOLD LAYER WORK STATIONS DIM VIEW
==============================================================
*/

CREATE VIEW gold_layer.dim_work_stations_dev AS
SELECT
    d.work_station_id,
    d.work_station,
    d.equipment
FROM silver_layer.dim_work_stations_dev d;
GO

/*
==============================================================
            GOLD LAYER FAILURES DIM VIEW
==============================================================
*/

CREATE VIEW gold_layer.dim_failures_dev AS
SELECT
    d.failure_id,
    d.failure_type,
    d.sub_code
FROM silver_layer.dim_failures_dev d;
GO

/*
==============================================================
            GOLD LAYER PRODUCT DIM VIEW
==============================================================
*/

CREATE VIEW gold_layer.dim_product_dev AS
SELECT
    d.product_id,
    d.full_line,
    d.version,
    d.manufacturer,
    d.model,
    d.product
FROM silver_layer.dim_product_dev d;
GO

/*
==============================================================
            GOLD LAYER TEAM LEADER STATUS DIM VIEW
==============================================================
*/

CREATE VIEW gold_layer.dim_team_leaders_status_dev AS
SELECT
    d.team_leader_status_id,
    d.shift,
    d.team_leader,
    d.num_operators
FROM silver_layer.dim_team_leaders_status_dev d;
GO

/*
==============================================================
            GOLD LAYER PRODUCT DETAILS DIM VIEW
==============================================================
*/

CREATE VIEW gold_layer.dim_product_details_dev AS
SELECT
    d.product_details_id,
    d.version,
    d.cycle_time
FROM silver_layer.dim_product_details_dev d;
GO

/*
==============================================================
            GOLD LAYER BREAKDOWN FACT VIEW
==============================================================
*/

CREATE VIEW gold_layer.fact_breakdown_table_dev AS
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
GO

/*
==============================================================
            GOLD LAYER STATUS FACT VIEW (OEE)

The status fact enriched with the OEE calculation. The ratio
columns are CAST to DECIMAL(9,4) for clean presentation; as a
view there is no storage type to overflow.
==============================================================
*/

CREATE VIEW gold_layer.fact_status_enriched_dev AS
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
        CAST(CAST(ok_parts AS DECIMAL(9,4)) / NULLIF(total_produced, 0)                     AS DECIMAL(9,4)) AS quality,
        CAST((CAST(total_produced AS DECIMAL(9,4)) * (cycle_time/60)) / NULLIF(run_time, 0) AS DECIMAL(9,4)) AS performance,
        CAST(CAST(run_time AS DECIMAL(9,4)) / NULLIF(planned_production_time, 0)            AS DECIMAL(9,4)) AS availability
    FROM calc
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
    CAST(CAST(total_produced AS DECIMAL(9,4)) / NULLIF(fully_productive_time, 0)     AS DECIMAL(9,4)) AS pplh,
    (ok_parts - reworked_parts)                                                                       AS ok_first_parts,
    CAST(CAST(ok_parts - reworked_parts AS DECIMAL(9,4)) / NULLIF(total_produced, 0) AS DECIMAL(9,4)) AS ftq,
    CAST((availability * performance * quality)                                      AS DECIMAL(9,4)) AS oee
FROM metrics;
GO
