# Data Modeling Strategy for Gold Layer

This model takes two raw source tables and turns them into a star schema with two fact tables (galaxy schema). The dimension tables will be created on silver layer

## Source Tables (Bronze Layer)

- **wel_breakdown_data** — equipment failure and downtime events (line, work station, equipment, failure type, planned/unplanned downtime).
- **wel_status_data** — daily production status per line and shift (output, defects, rework, accidents, complaints, cycle time).

## Modeled Tables

The raw data is reshaped into two fact tables and their dimensions:

- **fact_breakdown_table** → linked to dim_failures, dim_work_station, and dim_product.
- **fact_status_table** → linked to dim_team_leaders_status and dim_product_details.
- **dim_dates** is shared by both fact tables for consistent date analysis.

## Action

Keep raw data as-is in the bronze layer, then model it into star schemas so the breakdown and production data are cleaned and ready for the gold_layer, where we will create new columns and apply some analytics for the business necessities.