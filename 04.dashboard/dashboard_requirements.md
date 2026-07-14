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

The KPIs are defined by manufacturer: **HAUSBERG** & **WEISSTECH**. The dataset was analyzed in the Jupyter notebook `03.scripts/python/eda_metrics.ipynb`, querying `gold_layer.fact_status_table_final_dev`.

| Metric | HAUSBERG | WEISSTECH | Total |
|---|---|---|---|
| Total rows of production | 163,603 | 164,044 | 327,647 |
| Rows above 85% OEE | 2,449 | 2,101 | — |
| % of rows above 85% OEE | 1.50% | 1.28% | — |

**Conclusion:** since we have few data to use the golden OEE rule of 85%, we'll base ourselves on the third quartile (75%).

#### 1.2.2. KPI Color Rules

| Color | Rule |
|---|---|
| 🟢 Green | Value at or above the green KPI goal. |
| 🟡 Yellow | 90% of the green KPI goals. The OEE metric will be 95% of the green one. |
| 🔴 Red | Below the minimum for yellow KPIs. |
| 🟣 Purple | Sometimes the performance surpasses 100% and this is incorrect. To call the user's attention we will display it with pink. |

#### 1.2.3. HAUSBERG KPI Goals

| KPI | 🟢 Green | 🟡 Yellow |
|---|---|---|
| OEE | 74.06% | 70.35% |
| Performance | 90.0% | 88.0% |
| Availability | 83.12% | 81.57% |
| Quality | 99.0% | 98.0% |
| FTQ | 97.74% | 87.96% |
| PPLH | 0.46 | 0.414 |

**HAUSBERG values of reference** (163,603 rows):

| | quality | performance | availability | pplh | ftq | oee |
|---|---|---|---|---|---|---|
| mean | 0.963564 | 0.895810 | 0.809305 | 0.331133 | 0.943570 | 0.688606 |
| std | 0.033856 | 0.139672 | 0.093739 | 0.170897 | 0.046006 | 0.076624 |
| min | 0.714300 | 0.373200 | 0.457100 | 0.067200 | 0.594600 | 0.310800 |
| 25% | 0.949200 | 0.830700 | 0.742900 | 0.182100 | 0.921600 | 0.639000 |
| 50% | 0.973300 | 0.911300 | 0.800000 | 0.263200 | 0.957100 | 0.691200 |
| 75% | 0.986300 | 0.992400 | 0.871400 | 0.468400 | 0.977400 | 0.740650 |
| max | 1.000000 | 1.149600 | 1.000000 | 0.834600 | 1.000000 | 0.999400 |

#### 1.2.4. WEISSTECH KPI Goals

| KPI | 🟢 Green | 🟡 Yellow |
|---|---|---|
| OEE | 73.77% | 70.08% |
| Performance | 90.0% | 88.0% |
| Availability | 82.79% | 81.26% |
| Quality | 99.0% | 98.0% |
| FTQ | 97.74% | 87.96% |
| PPLH | 0.46 | 0.414 |

**WEISSTECH values of reference** (164,044 rows):

| | quality | performance | availability | pplh | ftq | oee |
|---|---|---|---|---|---|---|
| mean | 0.960615 | 0.895217 | 0.809428 | 0.279251 | 0.939066 | 0.686102 |
| std | 0.033843 | 0.139902 | 0.093716 | 0.125909 | 0.045202 | 0.076183 |
| min | 0.729700 | 0.437900 | 0.450700 | 0.079300 | 0.634100 | 0.338400 |
| 25% | 0.944400 | 0.829600 | 0.743200 | 0.181800 | 0.915700 | 0.637000 |
| 50% | 0.968400 | 0.910250 | 0.802300 | 0.238400 | 0.949200 | 0.688600 |
| 75% | 0.984100 | 0.991900 | 0.871400 | 0.355400 | 0.972200 | 0.737725 |
| max | 1.000000 | 1.149600 | 1.000000 | 0.829700 | 1.000000 | 0.982900 |

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