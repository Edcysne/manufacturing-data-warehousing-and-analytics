-- ============================================================
-- SILVER LAYER - DQL HELPER QUERIES
-- Ad-hoc SELECT queries used to inspect and validate the silver layer.
-- ============================================================

-- Used to check the missing rows.
-- Everything that is on the bronze layer and not on the silver layer,
SELECT bf.*
FROM bronze_layer.wel_breakdown_data bf
LEFT JOIN silver_layer.fact_breakdown_table sf
    ON sf.source_id = bf.ID
WHERE sf.source_id IS NULL;


-- Discovered that we have evening and night in the same dataset
SELECT DISTINCT *
FROM bronze_layer.wel_status_data st
LIMIT 1000;