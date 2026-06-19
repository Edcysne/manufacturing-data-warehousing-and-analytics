-- ============================================================
-- HELPER SCRIPTS
-- Reusable SQL snippets for common schema maintenance tasks.
-- ============================================================

-- Code snippet to rename a table column
EXEC sp_rename 'silver_layer.fact_breakdown_table.event_time', 'duration', 'COLUMN';

-- Code snippet to add a FK
CONSTRAINT fk_Person FOREIGN KEY (PersonID) REFERENCES Persons(PersonID);

-- Server properties
SELECT SERVERPROPERTY('Edition')        AS edition,
       SERVERPROPERTY('ProductVersion') AS version;

-- Checking if current database is correct and silver_layer tables
SELECT DB_NAME() AS current_db;   -- should be db_manufacturing_warehouse

SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'silver_layer'
ORDER BY t.name;