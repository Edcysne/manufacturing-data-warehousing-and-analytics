# VBA Explanation

The VBA code takes all the production reports filled in by the team leaders, **joins them into two tables**, and **cleans the data**.

The two tables are:

- **`tbl_breakdowns`** — the breakdowns / stoppages data.
- **`tbl_status`** — the production summary for each shift.

During this process the data is cleaned (empty and irrelevant rows are removed) so the tables are ready to be used in the data warehouse.

It's possible to analyze all the process in the scripts folder.
