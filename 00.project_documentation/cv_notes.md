# CV Bullet Points - Manufacturing Data Warehouse & OEE Analytics

## What is this document?

A summary of this project written as CV bullet points. Instead of describing the repository, it condenses the work into the lines you would actually put on a résumé or a LinkedIn entry - one per engineering or analytics outcome, each tied to a real number.

Every figure comes from querying the finished warehouse directly (verified 2026-07-21), so
the numbers here match what the code in this repository produces.

## What matters to recruiters

Most portfolio projects list *tools*: "used Python, SQL and Power BI". That says nothing
about whether the tools were used well. What stands out instead:

- **Results with a number attached.** "Optimized a load" is invisible; "cut it from 57
  minutes to 3 minutes on 8.3M rows" is a conversation. Scale, runtime and percentages turn
  an activity into an achievement.
- **Engineering decisions, not just steps.** Pipelines, transaction control,
  quarantining bad data instead of deleting it - these show judgment about failure and
  auditability, which is what separates a data engineer from a script author.
- **Honesty about scope.** The data here is synthetic and the project is a portfolio build.
  Saying so up front is more convincing than overstating it, and it survives the follow-up
  questions an interview will bring.

---

## Full version (use 6-8 of these)

• Built an end-to-end data warehousing pipeline (Excel/VBA → Python → SQL Server → Power BI)
processing **8.8M production records** across **1,591 production days (2022-2026)**.

• Optimized the silver-layer transformation load **from 57 minutes to 3 minutes (-95%)** on
**8.3M rows** by refactoring row-based logic into set-based CTEs and adding clustered and
unique nonclustered indexes in T-SQL.

• Modeled a medallion architecture (Bronze/Silver/Gold) data warehouse in SQL Server using a
two-fact galaxy star schema with **5 conformed dimensions** and **15 business-ready gold views**.

• Developed an idempotent Extract & Load pipeline in Python (Pandas, OpenPyXL, PyODBC) with a
watermark log table and per-file transaction control (commit/rollback), enabling safe re-runs
and full success/error auditability of every load.

• Engineered a data-quality quarantine layer that isolated **29,764 physically impossible
records (7% of 426,963)** into an auditable view with zero data loss, keeping the OEE
calculation defined in a single source of truth.

• Eliminated **66,246 duplicate shift reports (13.4%)** using SQL window functions
(`ROW_NUMBER() OVER PARTITION BY`), with **zero fact rows lost** to dimension joins.

• Automated the historical backfill of **8.8M rows** through a `BULK INSERT` stored procedure
with `TABLOCK`, `TRY/CATCH` error handling and per-step runtime logging.

• Standardized data capture at the source with Excel VBA (event-driven macros, cascading data
validation, diacritic normalization), replacing manually consolidated shift reports.

• Implemented the OEE KPI (ISO 22400-2) and derived metrics (PPLH, FTQ, scrap cost in EUR)
across **144 production lines** as SQL gold-layer views.

• Executed exploratory data analysis in Jupyter (Pandas, SQLAlchemy) over **397,199 records**,
identifying that only **0.10%** met the 85% industry OEE benchmark and re-basing KPI targets on
the **75th percentile per manufacturer** (OEE 70.26% / 70.00%).

• Designed a 3-page interactive Power BI dashboard using DAX, field parameters, Pareto and
decomposition tree visuals, plus custom HTML/CSS/SVG card visuals.

• Aggregated OEE in DAX weighted by planned production time (`SUMX`) rather than a simple
average of ratios, ensuring statistically correct roll-ups across lines and shifts.

• Utilized Git for version control and VS Code for development, documenting the model in a
column-level gold-layer data catalog.

---

## Short version (What will be posted on Linkedin and displayed on my CV)

• Built an end-to-end data warehousing pipeline using Excel, VBA, python, SQL Server and Power BI, processing **8.8M production records** across 1,591 production days.

• Optimized the silver-layer load **from 57 minutes to 3 minutes (-95%)** on 8.3M rows using
set-based CTEs and index tuning in T-SQL.

• Modeled a Bronze/Silver/Gold medallion warehouse with a two-fact star schema (galaxy schema), eliminating
**13.4% duplicate records** and quarantining **7% invalid rows** into an auditable layer.

• Developed an Extract & Load pipeline in Python (Pandas, OpenPyXL, PyODBC) with watermark logging and transaction control for safe, auditable re-runs.

• Delivered an OEE (ISO 22400-2) Power BI dashboard over **144 production lines**, with KPI
targets derived from EDA in Jupyter (Pandas, SQLAlchemy) across 397,199 records.

---

## Notes

- Say "on a local SQL Server Express instance" if asked about the 57→3 min benchmark.
- The data is synthetic - describe it as a portfolio warehouse built on synthetic
  manufacturing data, never as production work for an employer.
- Azure SQL Database was prototyped only (free tier expired); don't claim cloud deployment.