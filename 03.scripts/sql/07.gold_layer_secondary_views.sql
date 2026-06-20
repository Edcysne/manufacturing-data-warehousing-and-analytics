/*
================================================================================================
                                GOLD LAYER - SECONDARY VIEWS
================================================================================================
DATABASE:   db_manufacturing_warehouse
SCHEMA:     gold_layer
------------------------------------------------------------------------------------------------
PURPOSE:    Thin filter views layered on top of gold_layer.fact_status_enriched_dev. The OEE math
            lives once in the enriched base; these two views only split its rows by data quality,
            so the clean and trash sides can never disagree on a formula.

OUTPUT:     fact_status_trash_dev  ->  rows that break a physical/measurement rule (quarantine).
            fact_status_table_dev  ->  the clean business-ready fact consumed by the dashboard.

RULES:      - run_time < 0       -> impossible in real life (bad source timings) -> trash.
            - performance > 1.14 -> beyond the 14% tolerance; cycle_time was mis-measured, so the
                                    figure is treated as wrong. Rows from 1.00 to 1. stay in the
                                    clean view on purpose (viewers still get a visible warning).
            - performance IS NULL (run_time = 0) is NOT trash and stays in the clean view.

NOTES:      - Views only: store no data, always reflect the current enriched/silver state.
            - The trash flag_* columns expose WHICH rule caught each row (a row may trip both).
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
DROP VIEW  IF EXISTS gold_layer.fact_status_table_dev;
GO

CREATE VIEW gold_layer.fact_status_trash_dev AS
SELECT
    *
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_enriched_dev]
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

CREATE VIEW gold_layer.fact_status_table_dev AS
SELECT * FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_enriched_dev]
WHERE run_time >= 0 AND performance <= 1.1496 AND oee <= 1                                    
GO