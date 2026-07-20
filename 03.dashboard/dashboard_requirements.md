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

### 1.1. Filters

The content of the Overview Report must be filterable by **day, week, month, quarter and year**.

### 1.2. Metrics and KPIs

The goals will be dictated by a separate document called: **KPI Goals**. By experience, the gold standard for high quality companies is: **90% of Availability, 95% of Performance, and 99% of Quality, resulting in an OEE of 85%**.

Since the data artificially generated has low scores, I will adjust the metric values so the dashboard displays the colors properly, otherwise everything would be red.

#### 1.2.1. EDA Summary (from `eda_metrics.ipynb`)

The KPIs are defined by manufacturer: **HAUSBERG** & **WEISSTECH**. The dataset was analyzed in the Jupyter notebook `02.scripts/python/eda_metrics.ipynb`, querying `gold_layer.fact_status_table_final_dev`.

| Metric | HAUSBERG | WEISSTECH | Total |
|---|---|---|---|
| Total rows of production | 198,631 | 198,568 | 397,199 |
| Rows above 85% OEE | 198 | 181 | — |
| % of rows above 85% OEE | 0.10% | 0.09% | — |

**Conclusion:** since we have few data to use the golden OEE rule of 85%, we'll base ourselves on the third quartile (75%).

#### 1.2.2. KPI Color Rules

| Color | Rule |
|---|---|
| 🟢 Green | Value at or above the green KPI goal. |
| 🟡 Yellow | Derived from the green goals: OEE and FTQ at 95% of green, PPLH at 90% of green, Performance and Quality relaxed slightly, and Availability recalculated as OEE ÷ (Performance × Quality). |
| 🔴 Red | Below the minimum for yellow KPIs. |
| 🟣 Purple | Sometimes the performance surpasses 100% and this is incorrect. To call the user's attention we will display it with purple. |

#### 1.2.3. HAUSBERG KPI Goals

| KPI | 🟢 Green | 🟡 Yellow |
|---|---|---|
| OEE | 70.26% | 66.75% |
| Performance | 90.0% | 88.0% |
| Availability | 78.86% | 77.40% |
| Quality | 99.0% | 98.0% |
| FTQ | 97.74% | 92.85% |
| PPLH | 12.33 | 11.10 |

**HAUSBERG values of reference** (198,631 rows):

| | quality | performance | availability | pplh | ftq | oee |
|---|---|---|---|---|---|---|
| mean | 0.963451 | 0.784194 | 0.882012 | 9.640994 | 0.943395 | 0.649877 |
| std | 0.033984 | 0.159126 | 0.120021 | 6.861431 | 0.046184 | 0.073557 |
| min | 0.714300 | 0.358400 | 0.457100 | 1.500000 | 0.594600 | 0.304300 |
| 25% | 0.949200 | 0.636000 | 0.780000 | 4.608900 | 0.921300 | 0.600500 |
| 50% | 0.973300 | 0.815100 | 0.880900 | 7.866700 | 0.956900 | 0.653400 |
| 75% | 0.986300 | 0.913000 | 1.000000 | 12.333300 | 0.977400 | 0.702600 |
| max | 1.000000 | 1.149600 | 1.000000 | 49.920000 | 1.000000 | 0.943900 |

#### 1.2.4. WEISSTECH KPI Goals

| KPI | 🟢 Green | 🟡 Yellow |
|---|---|---|
| OEE | 70.00% | 66.50% |
| Performance | 90.0% | 88.0% |
| Availability | 78.56% | 77.11% |
| Quality | 99.0% | 98.0% |
| FTQ | 97.20% | 92.34% |
| PPLH | 10.18 | 9.16 |

**WEISSTECH values of reference** (198,568 rows):

| | quality | performance | availability | pplh | ftq | oee |
|---|---|---|---|---|---|---|
| mean | 0.960456 | 0.783319 | 0.882343 | 8.117393 | 0.938794 | 0.647413 |
| std | 0.033989 | 0.158979 | 0.119818 | 5.318733 | 0.045387 | 0.073402 |
| min | 0.729700 | 0.365600 | 0.450700 | 1.422200 | 0.634100 | 0.298700 |
| 25% | 0.944400 | 0.635600 | 0.780700 | 4.458300 | 0.915300 | 0.598200 |
| 50% | 0.968300 | 0.814200 | 0.881300 | 6.584700 | 0.949000 | 0.651200 |
| 75% | 0.984100 | 0.911900 | 1.000000 | 10.185200 | 0.972000 | 0.700000 |
| max | 1.000000 | 1.149600 | 1.000000 | 49.216600 | 1.000000 | 0.947500 |

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
| 1 | Decomposition Tree | Layers between **Products → Breakdown Category → Breakdown Sub-Category**.