/*
================================================================================================
                                    BRONZE LAYER
================================================================================================
DATABASE:   db_manufacturing_warehouse
SCHEMA:     bronze_layer
------------------------------------------------------------------------------------------------
PURPOSE:    Stores raw production data exactly as extracted from the Excel "Production
            Summary" files, with NO cleaning or transformation applied. This is the
            landing zone for the EL (Extract & Load) process; all transformation happens
            downstream in the silver_layer.

SOURCE:     Excel "Summary Generator" workbooks, structured into tabular form by VBA macros
            and loaded into SQL via Python (Extract & Load only). Since the schema of the ETL
            pipeline in python got wrong due to subscription end, the date will be bulk inserted
            by a script in SQL.


VBA CODE:   - 1st Table VBA Code:

            '--------------------------------------------------------------
            '  1st Dataset - Only the breakdown's data
            '--------------------------------------------------------------
            wsDataset.Range("A1").Value = "ID"
            wsDataset.Range("B1").Value = "date"
            wsDataset.Range("C1").Value = "line"
            wsDataset.Range("D1").Value = "event_time"
            wsDataset.Range("E1").Value = "unplanned_downtime"
            wsDataset.Range("F1").Value = "planned_downtime"
            wsDataset.Range("G1").Value = "work_station"
            wsDataset.Range("H1").Value = "equipment"
            wsDataset.Range("I1").Value = "failure_type"
            wsDataset.Range("J1").Value = "sub_code"
            wsDataset.Range("K1").Value = "failure_description"

        - 2nd Table VBA Code:

            '--------------------------------------------------------------
            '  2nd Dataset - Values for the production status
            '--------------------------------------------------------------
            Dim startRow As Long
            startRow = wsDataset.Range("A10000").End(xlUp).Row + 2

            wsDataset.Cells(startRow, 1).Value =  "ID"
            wsDataset.Cells(startRow, 2).Value =  "date"
            wsDataset.Cells(startRow, 3).Value =  "line"
            wsDataset.Cells(startRow, 4).Value =  "shift"
            wsDataset.Cells(startRow, 5).Value =  "team_leader"
            wsDataset.Cells(startRow, 6).Value =  "num_operators"
            wsDataset.Cells(startRow, 7).Value =  "total_expected_output"
            wsDataset.Cells(startRow, 8).Value =  "total_produced"
            wsDataset.Cells(startRow, 9).Value =  "nok_parts"
            wsDataset.Cells(startRow, 10).Value = "reworked_parts"
            wsDataset.Cells(startRow, 11).Value = "accidents"
            wsDataset.Cells(startRow, 12).Value = "near_misses"
            wsDataset.Cells(startRow, 13).Value = "customer_complaints"
            wsDataset.Cells(startRow, 14).Value = "observations"
            wsDataset.Cells(startRow, 15).Value = "version"
            wsDataset.Cells(startRow, 16).Value = "cycle_time"

NOTE:       - Column names mirror the VBA output headers (see top of CREATE script).
            - 'date' in wel_breakdown_data is stored as text (dd/mm/yyyy); it is converted
                to a true DATE in the silver layer.
            - Each table is dropped and recreated on every run.
            - No business logic, no de-duplication, no type coercion beyond the raw schema.

------------------------------------------------------------------------------------------------
AUTHOR:     Eduardo Cysne
STARTED:    25/05/2026
================================================================================================
*/

/*
============================
TABLES CREATION
============================

- Based on the VBA code, we'll develop the tables.
- 1st Table VBA Code:

    '--------------------------------------------------------------
    '  1st Dataset - Only the breakdown's data
    '--------------------------------------------------------------
    wsDataset.Range("A1").Value = "ID"
    wsDataset.Range("B1").Value = "date"
    wsDataset.Range("C1").Value = "line"
    wsDataset.Range("D1").Value = "event_time"
    wsDataset.Range("E1").Value = "unplanned_downtime"
    wsDataset.Range("F1").Value = "planned_downtime"
    wsDataset.Range("G1").Value = "work_station"
    wsDataset.Range("H1").Value = "equipment"
    wsDataset.Range("I1").Value = "failure_type"
    wsDataset.Range("J1").Value = "sub_code"
    wsDataset.Range("K1").Value = "failure_description"

- 2nd Table VBA Code:

    '--------------------------------------------------------------
    '  2nd Dataset - Values for the production status
    '--------------------------------------------------------------
    Dim startRow As Long
    startRow = wsDataset.Range("A10000").End(xlUp).Row + 2

    wsDataset.Cells(startRow, 1).Value =  "ID"
    wsDataset.Cells(startRow, 2).Value =  "date"
    wsDataset.Cells(startRow, 3).Value =  "line"
    wsDataset.Cells(startRow, 4).Value =  "shift"
    wsDataset.Cells(startRow, 5).Value =  "team_leader"
    wsDataset.Cells(startRow, 6).Value =  "num_operators"
    wsDataset.Cells(startRow, 7).Value =  "total_expected_output"
    wsDataset.Cells(startRow, 8).Value =  "total_produced"
    wsDataset.Cells(startRow, 9).Value =  "nok_parts"
    wsDataset.Cells(startRow, 10).Value = "reworked_parts"
    wsDataset.Cells(startRow, 11).Value = "accidents"
    wsDataset.Cells(startRow, 12).Value = "near_misses"
    wsDataset.Cells(startRow, 13).Value = "customer_complaints"
    wsDataset.Cells(startRow, 14).Value = "observations"
    wsDataset.Cells(startRow, 15).Value = "version"
    wsDataset.Cells(startRow, 16).Value = "cycle_time"

*/

USE db_manufacturing_warehouse;
GO

-- Security Layer for Database Existance Checking
IF OBJECT_ID ('bronze_layer.wel_breakdown_data', 'U') IS NOT NULL
    DROP TABLE bronze_layer.wel_breakdown_data;

-- Creation of the first table
CREATE TABLE bronze_layer.wel_breakdown_data (
    ID                       VARCHAR(250) PRIMARY KEY,
    date                     VARCHAR(50),    
    line                     VARCHAR(100), 
    event_time               TIME(0),
    unplanned_downtime       INT,
    planned_downtime         INT, 
    work_station             VARCHAR(50),
    equipment                VARCHAR(50),
    failure_type             VARCHAR(50),
    sub_code                 VARCHAR(50),
    failure_description      NVARCHAR(MAX)    
);

-- Security Layer for Database Existance Checking
IF OBJECT_ID ('bronze_layer.wel_status_data', 'U') IS NOT NULL
    DROP TABLE bronze_layer.wel_status_data;

-- Creation of the second table
CREATE TABLE bronze_layer.wel_status_data (

    ID                          VARCHAR(250) PRIMARY KEY,
    date                        VARCHAR(50),
    line                        VARCHAR(100), 
    shift                       VARCHAR(10),
    team_leader                 VARCHAR(30),
    num_operators               INT,
    total_expected_output       INT,
    total_produced              INT,
    nok_parts                   INT,
    reworked_parts              INT,
    accidents                   INT,
    near_accidents              INT,
    customer_complaints         INT,
    observations                NVARCHAR(MAX),
    version                     VARCHAR(25),
    cycle_time                  DECIMAL(5,2)

);

-- This is a new table in the bronze_layer that I'm going to use to check if the data has
-- been already loaded into the model or not
IF OBJECT_ID ('bronze_layer.wel_file_log', 'U') IS NOT NULL DROP TABLE bronze_layer.wel_file_log;
CREATE TABLE bronze_layer.wel_file_log (

    ID              VARCHAR(250) PRIMARY KEY,
    file_name       VARCHAR(250),
    loaded_at       DATETIME DEFAULT GETDATE(),
    status          VARCHAR(50)  -- 'success' or 'error'

);