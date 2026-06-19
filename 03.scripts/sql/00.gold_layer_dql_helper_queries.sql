-- ============================================================
-- GOLD LAYER - DQL HELPER QUERIES
-- Ad-hoc SELECT queries used to inspect and validate the gold layer.
-- ============================================================


/* 
===============================================
				OLD DATASET!
===============================================
*/

-- A script I used to check the downtime
-- noticed the data was way poor distributed
-- Needed to create a new csv version

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
				NEW DATASET!
===============================================
*/

-- Notice 115 recors with negative run time, which in real life is impossible
-- Moved all the data to the trash table

SELECT *
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_table_dev]
WHERE run_time < 0;

-- In this other case, we can see that the performance is bigger than 100%.
-- This can happens sometimes, but it shouldn't. Usually, it happens when the cycle_time
-- is wrongly measured. I'll add a 10% tolerance, so the viewers can see
-- something is wrong. More than that we can assume is 100% wrong data.

SELECT *
FROM [db_manufacturing_warehouse].[gold_layer].[fact_status_table_dev]
WHERE performance > 1.1
ORDER BY performance DESC;
