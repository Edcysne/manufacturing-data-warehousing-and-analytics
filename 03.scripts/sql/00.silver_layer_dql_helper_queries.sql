-- Used to check the missing rows.
-- Everything that is on the bronze layer and not on the silver layer,
SELECT bf.*
FROM bronze_layer.wel_breakdown_data bf
LEFT JOIN silver_layer.fact_breakdown_table sf
    ON sf.source_id = bf.ID
WHERE sf.source_id IS NULL;