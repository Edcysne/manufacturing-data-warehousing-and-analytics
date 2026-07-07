# Project Overview

This project focuses on building a data pipeline and analytical system for a manufacturing environment where production performance is tracked manually using Excel.

This public version starts from the presupposition that all the automations insert data from multiple Production software into an Excel report for the necessity of physical storage. From there, we Extract, Transform, and Load the data in our project.

Tools used:

Excel (VBA) -> Data Input Standardization <br/>
Python -> Data Extraction and Loading <br/>
SQL -> Data Storage and Data Transformation <br/>
Azure SQL Database -> Centralized data storage & transformation <br/>
Power BI -> Data visualization <br/>

## Phase 1 - Data Standardization

A standardized input system is created using advanced Excel formulas and features.

Instead of multiple inconsistent files, a single structured template (Summary Generator) is used to capture production data. VBA is applied to enforce validation rules and ensure consistent formatting.

## Phase 2 - Data Ingestion

Python is used to extract structured data from Excel files and load it into a centralized database.

This replaces the previous file-based approach with a controlled and repeatable data ingestion process.

## Phase 3 - Data Modeling

A data warehouse is implemented in Azure SQL Database using a layered approach:

Bronze 🟤 → Raw data <br/>
Silver ⚪ → Cleaned and structured data <br/>
Gold 🟡 → KPI-ready data <br/>

This enables efficient querying and supports analytical use cases.

## Phase 4 - Analytics Layer

Power BI is used to build dashboards focused on production performance.

Key analyses include:

1. OEE breakdown by operational dimensions <br/>
2. Performance comparison across shifts and production areas <br/>
3. Identification of inefficiencies and recurring issues <br/>

## Output

The final output of this project is a fully integrated analytical solution, transforming manual production tracking into a system capable of supporting data-driven decision-making in a manufacturing context.
