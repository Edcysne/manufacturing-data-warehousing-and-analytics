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

-- Confirms the historic span. The date dimension no longer exists
-- (facts carry full_date), so the span is read off the fact itself.
SELECT
    MIN(full_date) AS first_date,
    MAX(full_date) AS last_date
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_enriched_dev];

-- Lowest performance with OEE > 1 (sorted ascending) gives 1.1496.
SELECT *
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_table_dev]
WHERE performance > 0 AND oee > 1
ORDER BY performance ASC;

-- Script that I used to check all the data that was not included in the fact_status_table_dev
SELECT a.*
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_enriched_dev] AS a
LEFT OUTER JOIN [db_manufacturing_warehouse].[gold_layer].[fact_status_table_dev] AS b
    ON a.[your_key_column] = b.[your_key_column]
WHERE b.[your_key_column] IS NULL;

-- Counting the rows of each table to check if any was dropped
SELECT COUNT(*) AS enriched_rows FROM gold_layer.fact_status_enriched_dev;
SELECT COUNT(*) AS table_rows    FROM gold_layer.fact_status_table_dev;
SELECT COUNT(*) AS trash_rows    FROM gold_layer.fact_status_trash_dev;

-- Checking if all abc shifts are correct
-- Here I could verify that I have only 4 shifts (Shift A, Shift B, Shift C, Shift D)
-- And all Lenghts are 7, which is the expected
SELECT DISTINCT
shift_abc,
LEN(shift_abc) AS abc_size
FROM [db_manufacturing_warehouse].[gold_layer].[dim_team_leaders_status_final_dev];