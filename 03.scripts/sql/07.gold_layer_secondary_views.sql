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
    *,
    CASE WHEN run_time < 0         THEN 1 ELSE 0 END AS flag_negative_run_time,
    CASE WHEN performance >= 1.1496 THEN 1 ELSE 0 END AS flag_performance_over_tolerance
FROM gold_layer.fact_status_enriched_dev
WHERE run_time < 0 
    OR (performance >= 1.1496 AND oee >= 1)
    OR (run_time = 0 AND (ok_parts > 0 OR nok_parts > 0));
GO

/*
===========================================================
                GOLD LAYER FACT STATUS TABLE
===========================================================
*/

CREATE VIEW gold_layer.fact_status_table_dev AS
SELECT * FROM gold_layer.fact_status_enriched_dev
WHERE run_time >= 0                                                -- NOT rule A (negative run_time)
    AND (run_time = 0 OR NOT (performance >= 1.1496 AND oee >= 1)) -- NOT rule B (perf over tolerance)
    AND NOT (run_time = 0 AND (ok_parts > 0 OR nok_parts > 0));    -- NOT rule C (zero runtime w/ parts)
GO