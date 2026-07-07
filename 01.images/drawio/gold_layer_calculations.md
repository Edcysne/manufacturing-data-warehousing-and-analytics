# OEE & Production Metrics - Calculations
According to experience and the website https://www.leanproduction.com/oee/, the main metrics are:

## Inputs
- `total_produced`
- `nok_parts`
- `reworked_parts`
- `all_time`

## Calculations

| Metric | Formula |
|---|---|
| `ok_parts` | `total_produced - nok_parts` |
| `quality` | `ok_parts / total_produced` |
| `planned_production_time` | `all_time - total planned downtime` |
| `availability_loss` | `total unplanned downtime` |
| `run_time` | `planned_production_time - total unplanned downtime` |
| `performance` | `(total_produced * cycle_time) / run_time` |
| `availability` | `run_time / planned_production_time` |
| `fully_productive_time` | `all_time - unplanned_downtime - planned_downtime` |
| `pplh` | `total_produced / fully_productive_time` |
| `ok_first_parts` | `ok_parts - reworked_parts` |
| `ftq` | `ok_first_parts / total_produced` |
| `oee` | `availability x performance x quality` |