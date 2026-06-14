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