-- ============================================================
-- BRONZE LAYER - DQL HELPER QUERIES
-- Ad-hoc SELECTs used to inspect the bronze layer and to derive
-- the data-quality rules that drive the clean / trash split.
-- Not part of any build step; safe to run on demand.
-- ============================================================


SELECT DISTINCT 
TRIM(cycle_time)
FROM bronze_layer.status_data;

-- Notice that with this script we can see that the len and trimmed len are 6.
-- There is something suspicious, since 208.0 must have 5 characters of len and the trim is not removing
-- the blank or special character. That lead us to on conclusion: The extra space is not a simple blank, it
-- must be a CHAR(13) or CHAR(10).
SELECT TOP 20
    t.cycle_time,
    LEN(t.cycle_time)              AS raw_len,
    LEN(TRIM(t.cycle_time))        AS trimmed_len,
    CAST(t.cycle_time AS VARBINARY(20)) AS raw_bytes
FROM bronze_layer.status_data
WHERE cycle_time IS NOT NULL;

-- Here the result is more interesting. The len and trimmed len are now 5, which is correct.
-- If you try to cast the cycle time as DECIMAL(5,2), you'll be able to do it.
SELECT TOP 20
    t.cycle_time,
    LEN(t.cycle_time)              AS raw_len,
    LEN(TRIM(t.cycle_time))        AS trimmed_len,
    CAST(t.cycle_time AS VARBINARY(20)) AS raw_bytes
FROM (SELECT DISTINCT 
NULLIF(TRIM(REPLACE(REPLACE(cycle_time, CHAR(13), ''), CHAR(10), '')), '') AS cycle_time
FROM bronze_layer.status_data) t
WHERE t.cycle_time IS NOT NULL;

-- Identify the column datatype script
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bronze_layer'
  AND TABLE_NAME = 'status_data'
  AND COLUMN_NAME = 'cycle_time';