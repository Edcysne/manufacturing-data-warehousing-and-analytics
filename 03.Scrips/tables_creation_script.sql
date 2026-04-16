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
    wsDataset.Range("D1").Value = "schedule"
    wsDataset.Range("E1").Value = "unplanned_stoppages"
    wsDataset.Range("F1").Value = "planned_stoppages"
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
    date                     DATE,    
    line                     VARCHAR(100), 
    Schedule                 TIME(0),
    unplanned_stoppages      INT,
    planned_stoppages        INT, 
    work_station             DECIMAL(2,2),
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
    date                        DATE,
    line                        VARCHAR(100), 
    shift                       VARCHAR(10),
    team_leader                 VARCHAR(30),
    num_operators               INT,
    total_expected_output       INT,
    total_produced              INT,
    nok_parts                   INT,
    reworked_parts              INT,
    accidents                   INT,
    near_misses                 INT,
    customer_complaints         INT,
    observations                VARCHAR(MAX),
    version                     VARCHAR(25),
    cycle_time                  DECIMAL(5,2)

);
