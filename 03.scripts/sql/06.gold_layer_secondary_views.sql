/*
================================================================================================
                                GOLD LAYER - SECONDARY VIEWS
================================================================================================
DATABASE:   db_manufacturing_warehouse_pub
SCHEMA:     gold_layer
------------------------------------------------------------------------------------------------
PURPOSE:    The final, dashboard-facing presentation layer. It sits on top of the gold base
            views from 06.gold_layer.sql and gives the BI model ONE consistent set of *_final_dev
            views to connect to. Two kinds of view live here:
              1. The status fact split: thin filter views over gold_layer.fact_status_enriched_dev.
                 The OEE math lives once in the enriched base; these views only split its rows by
                 data quality, so the clean and trash sides can never disagree on a formula.
              2. The dimensions and the breakdown fact: thin passthroughs over their 06 gold views,
                 restated here so the whole final model is sourced from one layer.

OUTPUT:     fact_status_trash_dev          ->  status rows that break a physical/measurement rule.
            fact_status_table_dev          ->  the clean business-ready status fact.
            fact_breakdown_final_dev       ->  the breakdown fact for the dashboard.
            dim_work_stations_final_dev    ->  conformed dimensions for the dashboard.
            dim_failures_final_dev
            dim_product_final_dev
            dim_team_leaders_status_final_dev
            dim_product_details_final_dev

RULES:      - run_time < 0       -> impossible in real life (bad source timings) -> trash.
            - performance > 1.14 -> beyond the 14% tolerance; cycle_time was mis-measured, so the
                                    figure is treated as wrong. Rows from 1.00 to 1. stay in the
                                    clean view on purpose (viewers still get a visible warning).
            - performance IS NULL (run_time = 0) is NOT trash and stays in the clean view.

NOTES:      - Views only: store no data, always reflect the current enriched/silver state.
            - There is NO date dimension: both facts carry full_date directly, and the
              calendar attributes come from the BI-side calendar table
              (03.scripts/powerbi/calendar_table.md).
            - The dim/breakdown final views are full passthroughs (SELECT *): dimensions keep every
              member and the breakdown fact keeps every row. The clean/trash split is a status-fact
              concern only; the breakdown is an independent fact with its own report.
            - SELECT * in a view does not auto-track base column changes in T-SQL; if a 06 gold view
              gains/drops a column, re-run this script (or sp_refreshview) so the passthrough follows.
            - Script is idempotent: drops any prior view of the same name before (re)creating it.
            - T-SQL requires CREATE VIEW to be the first statement in a batch, hence GO.

------------------------------------------------------------------------------------------------
AUTHOR:     Eduardo Cysne
STARTED:    06/19/2026
================================================================================================
*/

/*
===========================================================
                GOLD LAYER FACT TRASH TABLE
===========================================================
*/

DROP VIEW  IF EXISTS gold_layer.fact_status_trash_dev;
DROP VIEW  IF EXISTS gold_layer.fact_status_trash_final_dev;
DROP VIEW  IF EXISTS gold_layer.fact_status_table_final_dev;
DROP VIEW  IF EXISTS gold_layer.fact_breakdown_final_dev;

-- dim_date_final_dev is never recreated: the date dimension was eliminated
-- (facts carry full_date). The DROP only migrates a prior run.
DROP VIEW  IF EXISTS gold_layer.dim_date_final_dev;
DROP VIEW  IF EXISTS gold_layer.dim_work_stations_final_dev;
DROP VIEW  IF EXISTS gold_layer.dim_failures_final_dev;
DROP VIEW  IF EXISTS gold_layer.dim_product_final_dev;
DROP VIEW  IF EXISTS gold_layer.dim_team_leaders_status_final_dev;
DROP VIEW  IF EXISTS gold_layer.dim_product_details_final_dev;
GO

CREATE VIEW gold_layer.fact_status_trash_final_dev AS
SELECT
    *
FROM [db_manufacturing_warehouse_pub].[gold_layer].[fact_status_enriched_dev]
WHERE run_time < 0
   OR run_time IS NULL
   OR performance > 1.1496 
   OR performance IS NULL
   OR oee > 1 
   OR oee IS NULL;
GO

/*
===========================================================
                GOLD LAYER FACT STATUS TABLE
===========================================================
*/

CREATE VIEW gold_layer.fact_status_table_final_dev AS
SELECT * FROM [db_manufacturing_warehouse_pub].[gold_layer].[fact_status_enriched_dev]
WHERE run_time >= 0 AND performance <= 1.1496 AND oee <= 1
GO

/*
===========================================================
            GOLD LAYER FINAL BREAKDOWN FACT VIEW

Passthrough over the 06 gold breakdown fact. No data-quality
split applies here: the breakdown is an independent fact with
its own report, so every row is kept. You can manage the
breakdown data from trash tables inside Power BI.
===========================================================
*/

CREATE VIEW gold_layer.fact_breakdown_final_dev AS
SELECT * FROM [db_manufacturing_warehouse_pub].[gold_layer].[fact_breakdown_table_dev];
GO

/*
===========================================================
            GOLD LAYER FINAL WORK STATIONS DIM VIEW
===========================================================
*/

CREATE VIEW gold_layer.dim_work_stations_final_dev AS
SELECT * FROM [db_manufacturing_warehouse_pub].[gold_layer].[dim_work_stations_dev];
GO

/*
===========================================================
            GOLD LAYER FINAL FAILURES DIM VIEW
===========================================================
*/

CREATE VIEW gold_layer.dim_failures_final_dev AS
SELECT * FROM [db_manufacturing_warehouse_pub].[gold_layer].[dim_failures_dev];
GO

/*
===========================================================
            GOLD LAYER FINAL PRODUCT DIM VIEW
===========================================================
*/

CREATE VIEW gold_layer.dim_product_final_dev AS
SELECT * FROM [db_manufacturing_warehouse_pub].[gold_layer].[dim_product_dev];
GO

/*
===========================================================
        GOLD LAYER FINAL TEAM LEADER STATUS DIM VIEW
===========================================================
*/

CREATE VIEW gold_layer.dim_team_leaders_status_final_dev AS
SELECT * FROM [db_manufacturing_warehouse_pub].[gold_layer].[dim_team_leaders_status_dev];
GO

/*
===========================================================
        GOLD LAYER FINAL PRODUCT DETAILS DIM VIEW
===========================================================
*/

CREATE VIEW gold_layer.dim_product_details_final_dev AS
SELECT * FROM [db_manufacturing_warehouse_pub].[gold_layer].[dim_product_details_dev];
GO