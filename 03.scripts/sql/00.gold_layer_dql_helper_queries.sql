-- ============================================================
-- GOLD LAYER - DQL HELPER QUERIES
-- Ad-hoc SELECTs used to inspect the gold layer and to derive
-- the data-quality rules that drive the clean / trash split.
-- Not part of any build step; safe to run on demand.
-- ============================================================


/*
===============================================
                OLD DATASET
===============================================
*/

-- Sanity check on downtime totals for a single source file.
-- Revealed the downtime was very poorly distributed in the old
-- CSVs, which is what prompted building a new dataset version.

SELECT
SUM(unplanned_downtime) AS total_unplanned_downtime,
SUM(planned_downtime) AS total_planned_downtime
FROM(
	SELECT TOP 1000
	source_id,
	unplanned_downtime,
	planned_downtime
	FROM [db_manufacturing_warehouse].[gold_layer].[fact_breakdown_table_dev]
	WHERE source_id LIKE '01012026 Shift C.xlsmD BMW M550i A-PILLAR%') tbl;


/*
===============================================
                NEW DATASET
===============================================
*/

-- RULE 1 - negative run_time.
-- 115 rows came back with run_time < 0, which is physically
-- impossible (bad source timings). These are quarantined into
-- the trash view instead of being shown in the business fact.

SELECT *
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_table_dev]
WHERE run_time < 0;

-- RULE 2 - performance above tolerance.
-- performance > 100% can occur, but it shouldn't: it usually means
-- cycle_time was mis-measured. A tolerance is allowed so viewers can
-- still see "something is wrong"; beyond it the figure is treated as
-- fully wrong and sent to the trash view. The cut-off (1.1496) is
-- derived just below.

SELECT *
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_table_dev]
WHERE performance > 1.1496
ORDER BY performance DESC;

-- Deriving the cut-off:
-- The history spans 2022 onward (4 years), so there is enough data to
-- set the threshold empirically. The query below shows the lowest
-- performance that still yields an OEE above 1 is 1.1496 (114.96%).
-- From that point up, the row is impossible and goes to the trash view.

-- Confirms the historic span (oldest year first).
SELECT TOP 10000 *
FROM [db_manufacturing_warehouse].[gold_layer].[dim_date_dev]
ORDER BY year_num ASC;

-- Lowest performance with OEE > 1 (sorted ascending) gives 1.1496.
SELECT *
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_table_dev]
WHERE performance > 0 AND oee > 1
ORDER BY performance ASC;