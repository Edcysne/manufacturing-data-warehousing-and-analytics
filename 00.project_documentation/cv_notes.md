# CV Bullet Points

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

## Bullet Points (What will be displayed on my CV)

- Built an end-to-end data warehousing solution using Excel, VBA, python, SQL Server and Power BI, processing **8.8M production records** across 1,591 production days and displaying only current year data;
- Optimized the silver-layer load **from 57 minutes to 3 minutes (-95%)** on 8.3M rows using set-based CTEs and indexes in T-SQL;
- Modeled a medallion warehouse architecture (Bronze, Silver, Gold) with a two-fact star schema (galaxy schema), eliminating **13.4% duplicate records** and quarantining **7% invalid rows** into an auditable layer;
- Developed an EL (Extract & Load) pipeline in Python (Pandas, OpenPyXL, PyODBC) with log and transaction control for safe, auditable re-runs;
- Delivered Power BI Reports with Manufacturing KPIs (ISO 22400-2) targets derived from EDA in Jupyter (Pandas, SQLAlchemy).