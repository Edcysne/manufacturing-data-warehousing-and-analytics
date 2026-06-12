-- ============================================================
-- GOLD LAYER - DQL HELPER QUERIES
-- Ad-hoc SELECT queries used to inspect and validate the gold layer.
-- ============================================================

-- A script I used to check the downtime
-- noticed the data was way poor distributed
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