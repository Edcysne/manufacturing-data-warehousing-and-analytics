# Data Modeling Strategy for Gold Layer

This model takes two raw source tables and turns them into a star schema with two fact tables (galaxy schema). The dimension tables will be created on silver layer

## Source Tables (Bronze Layer)

- **breakdown_data** - equipment failure and downtime events (line, work station, equipment, failure type, planned/unplanned downtime).
- **status_data** - daily production status per line and shift (output, defects, rework, accidents, complaints, cycle time).

## Modeled Tables

The raw data is reshaped into two fact tables and their dimensions:

- **fact_breakdown_table** → linked to dim_failures, dim_work_station, dim_product, and dim_team_leaders_status (the shift and crew letter are recovered from the report file name embedded in the source ID).
- **fact_status_table** → linked to dim_team_leaders_status and dim_product_details.
- There is **no date dimension**: both fact tables carry the calendar date directly (`full_date`), and the date attributes (week, month, quarter, ...) come from the calendar table built on the BI side (`03.scripts/powerbi/calendar_table.md`).

## Action

Keep raw data as-is in the bronze layer, then model it into star schemas so the breakdown and production data are cleaned and ready for the gold_layer, where we will create new columns and apply some analytics for the business necessities.