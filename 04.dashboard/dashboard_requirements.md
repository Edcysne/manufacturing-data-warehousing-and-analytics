# Dashboard Requirements

This document describes the dashboards to be built and the requirements requested by the client.

## 1. Overview Report

| # | Visual | Description |
|---|--------|-------------|
| 1 | Matrix table | OEE information for all lines: **OEE, Performance, Availability, Quality, NOK Parts, Total Unplanned Downtime**. |
| 2 | Column chart | **OEE by Team Leader**, with a parameter filter to switch the x-axis between *Team Leader*, *Shift* and *Product*. |
| 3 | Gauge chart | Track **OEE** against a fixed target. |
| 4 | 5 Cards (or similar visuals) | Display **Performance, Availability, Quality, PPLH, FTQ and Scrap Costs**. |
| 5 | Column chart | **Total scrap per product**, with a parameter filter to switch the x-axis between *Team Leader*, *Shift* and *Product*. |

The content of the Overview Report must be filterable by **day, week, month, quarter and year**.

## 2. Breakdown Report

| # | Visual | Description |
|---|--------|-------------|
| 1 | Gauge chart | Track **OEE** against a fixed target. |
| 2 | 3 Cards (or similar visuals) | Display **Performance** (and related values). |
| 3 | Pareto chart | Distribution of **unplanned failures per line**, with a parameter to also show the distribution **per failure category**. |
| 4 | Table | Display the **unplanned breakdown data**. |
| 5 | Area chart | **Unplanned breakdowns by time** (00:00 - 23:59). |
| 6 | Horizontal bar chart | **Total lost by sub-category**. |

## 3. Breakdown Deep Search Report

| # | Visual | Description |
|---|--------|-------------|
| 1 | Decomposition Tree | Layers between **Breakdown Category → Breakdown Sub-Category → Products**. |