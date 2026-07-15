/*
==============================
DATABASE AND SCHEMA CREATION
==============================

I've already created the database in Azure Portal.
Even so, I'll write the full code of database creation.

!!!!! WARNING !!!!!
- This code will drop the database db_manufacturing_warehouse if it exists.

*/

USE master;
GO


IF EXISTS( SELECT 1 FROM sys.databases WHERE name = 'db_manufacturing_warehouse' )
BEGIN
	ALTER DATABASE db_manufacturing_warehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE db_manufacturing_warehouse;
END;
GO

-- Database Creation
CREATE DATABASE db_manufacturing_warehouse;
GO

USE db_manufacturing_warehouse;
GO

-- Schemas Creation

CREATE SCHEMA bronze_layer;
GO

CREATE SCHEMA silver_layer;
GO

CREATE SCHEMA gold_layer;
