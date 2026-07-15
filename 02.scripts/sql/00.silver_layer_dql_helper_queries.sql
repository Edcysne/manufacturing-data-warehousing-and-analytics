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

/*
===============================================================================================================
                                        THE PARTIAL DUPLICATE SHIFT PROBLEM

This is a test I did using Claude to solve a problem I was having in Power BI: Partial Duplication of data.

The problem is the following one:
('01012024 Shift C', '2024-01-01', 'A BMW X7 C-PILLAR', 'evening', 'Shift C'),  
('01012024 Shift D', '2024-01-01', 'A BMW X7 C-PILLAR', 'evening', 'Shift D'),

You can't have a shift C and a Shift D that worked in the same day, in the same line and in the same shift.
Since the line is unique, this is impossible. 

To solve this problem I would ask to the production manager what to do in this case. Since It's an imaginary
scenario, what would be consider correct for this case will be to ignore the higher shift. In this example,
I will ignore the shift D line and keep the shift C.

The script below is what I used to test the logic
===============================================================================================================
*/


DROP TABLE IF EXISTS table_testing;

CREATE TABLE table_testing (
    source_id  VARCHAR(100),
    full_date  DATE,
    full_line  VARCHAR(100),
    shift      VARCHAR(20),
    shift_abc  VARCHAR(20)
);

INSERT INTO table_testing (source_id, full_date, full_line, shift, shift_abc) VALUES
('01012024 Shift C', '2024-01-01', 'A BMW X7 C-PILLAR', 'evening', 'Shift C'),
('01012024 Shift D', '2024-01-01', 'A BMW X7 C-PILLAR', 'evening', 'Shift D'),
('02012024 Shift A', '2024-01-02', 'A BMW X7 C-PILLAR', 'morning', 'Shift A'),
('02012024 Shift B', '2024-01-02', 'A BMW X7 C-PILLAR', 'morning', 'Shift B'),
('02012024 Shift D', '2024-01-02', 'A BMW X7 C-PILLAR', 'morning', 'Shift D'),
('03012024 Shift B', '2024-01-03', 'A BMW X7 B-PILLAR', 'evening', 'Shift B'),
('03012024 Shift C', '2024-01-03', 'A BMW X7 B-PILLAR', 'morning', 'Shift C'),
('03012024 Shift D', '2024-01-03', 'A BMW X7 B-PILLAR', 'night', 'Shift D');

-- The partition logic I will use to "rank" the equal rows 
SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY full_date, full_line, shift
            ORDER BY shift_abc ASC
        ) AS rn
FROM table_testing
ORDER BY full_date, full_line, rn;

-- CTE to create a virtual table with the ranking values without displaying
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY full_date, full_line, shift
               ORDER BY shift_abc ASC
           ) AS rn
    FROM table_testing
)

-- The number 1 will always be the lower alphabetical shift when duplicates exist
SELECT * FROM ranked WHERE rn = 1 ORDER BY full_date, full_line;

-- Drop table in the end. It's just a test.
DROP TABLE table_testing;

-- Test: strip the trailing '_<row number>' suffix from source_id.
-- SUBSTRING + CHARINDEX cut the string at the first underscore, keeping only the report file name part.
DROP TABLE IF EXISTS table_testing;

CREATE TABLE table_testing (
    source_id     VARCHAR(100),
    source_id_new VARCHAR(100)
);

INSERT INTO table_testing (source_id) VALUES
('03012025 Shift D.xlsmD MERCEDEZ GLE 53 FRONT BUMP_15'),
('03012025 Shift D.xlsmD MERCEDEZ GLE 53 FRONT BUMP_1')

DROP TABLE IF EXISTS table_testing2;
SELECT 
source_id,
SUBSTRING(source_id, 0, CHARINDEX('_', source_id)) AS source_id_new
INTO table_testing2
FROM table_testing;

SELECT * FROM table_testing2

DROP TABLE table_testing;
DROP TABLE table_testing2;

-- When running the new silver layer with the new data a few rows appear in the breakdown but not in the status database
-- Since I'm really tired of this for now, I'll just ignore ;)
-- Sincerity is everything
-- With those helper queries, you can check the missing data

-- how many stg_breakdown2 rows fail to find a matching product?
SELECT COUNT(*) 
FROM silver_layer.stg_breakdown2 s
LEFT JOIN silver_layer.dim_product_dev p ON p.full_line = s.full_line
WHERE p.product_id IS NULL;

-- All the lines that have breakdown associated, but not status
SELECT *
FROM silver_layer.stg_breakdown2 s
LEFT JOIN silver_layer.stg_status st
    ON st.full_date = s.full_date
    AND st.full_line = s.full_line
    AND st.shift_abc = s.shift_abc
    AND st.shift = s.shift
WHERE st.source_id IS NULL;