# Phase 1 - Excel Standardization (Summary Generator)

This document explains everything that was built inside the Excel layer of the
project: the **Excel Reports**.

> **Why this phase exists.** The company (LOMPSTAR) tracked production performance
> in inconsistent, manually-filled `.xlsx` files with no validation, no macros and
> no storage. Phase 1 replaces that with a single, controlled template that
> *enforces* how data is entered, so that everything downstream (Python EL → Azure
> SQL Bronze/Silver/Gold → Power BI) receives clean, predictable input. See
> `project_description.md` §1.6 Step 1 for the business framing.

---

## The Excel Structure

| `Shift X DDMMYYYY.xlsm` | Macro-enabled (OOXML) | One output file per shift/day, stored under `Production Reports/<year>/<month>/`. Holds one or more `CTRL *` report sheets plus a hidden `Dataset` sheet. |

The `.xlsb` was chosen for the master because it loads faster and is more compact
for a heavily-formula'd, multi-sheet template; the generated reports are `.xlsm`
so they remain macro-enabled but readable by the Python EL pipeline.

## Excel Formulas and Structure

## 1. Data Validation (Cascading Dropdowns)

| Cell range | Validation source |
|------------|-------------------|
| `N14:P94` (work station) | `INDIRECT($Z$2 & "working_stations")` |
| `Q14:S94`, `W14:Y94` (equipment / failure) | `INDIRECT(N14)` |
| `T..:V..` (breakdown analysis) | `breakdown_dropdown` (= `breakdown_analysis[]` table) |
| `G101:L115` (KPI / team rows) | `INDIRECT($Z$4)` |
| `E5` (date) | `type="date", >= 41275` |
| `G14 … G89` (parts produced/hour) | `type="decimal", >= 0` |

## 2. Normalized Lookup Key

```excel
Z2 = SUBSTITUTE( SUBSTITUTE( LOWER(AH2), " ", "_" ) & "_", "-", "" )
```

## 3. Accent / Diacritic Normalization

```excel
Z4 = LOWER(
       SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(
       SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(
       SUBSTITUTE( Z5, " ", "_"),
       "ã","a"),"â","a"),"á","a"),"à","a"),"ä","a"),"ç","c"),
       "é","e"),"ê","e"),"í","i"),"ó","o"),"ô","o"),"ú","u")
     ) & "_" & "equipa"
```

## 4. Time Grid

```excel
C14  = IF($Q$5="X", IF(WEEKDAY($E$5)=2, TIME(0,0,0), TIME(23,50,0)),
        IF($R$5="X", TIME(7,10,0),
        IF($S$5="X", TIME(15,30,0), "")))
C18  = IFERROR(TIME(HOUR(C14)+1, 0, 0), "")        ' each row = +1 hour
K32  = IF(Q5="X",10, IF(R5="X",10, IF(S5="X",10,0))) ' scheduled break minutes
M14  = IF(K14+I14=0, "", K14+I14)                    ' downtime per slot, blank if zero
```

## 5. Named Ranges

| Named range | Cell | Formula / meaning |
|-------------|------|-------------------|
| `total_produced` | `G93` | `=SUM` of every hourly production slot |
| `nok_parts` | `Q99` | non-conforming parts |
| `reworked_parts` | `W99` | reworked parts |
| `planned_downtime` | `K95` | `=SUM(K14:L94)` |
| `unplanned_downtime` | `I95` | `=SUM(I14:J94)` |
| `efficiency` | `W108` | target efficiency |
| `cycle_time_welding` | `W111` | resolved cycle time |
| `number_workers` | `Q102` | operators on the line |

## 6. KPI / OEE Formulas

```excel
Q105 = IFERROR( IF(total_produced>0, nok_parts/total_produced, 0), 0)     ' NOK rate
Q108 = IFERROR( (total_produced - reworked_parts) / total_produced, 0)    ' Quality
Q111 = IF(total_produced=0, 0,
         unplanned_downtime + planned_downtime
         - SUMIF($T$14:$V$94,"No_Production",$M$14:$M$94))                ' net downtime
W111 = IFERROR( INDIRECT(nome_kpis_sol1 & "cycle_time"), "-")            ' cycle time lookup
E7   = "Goal With " & TEXT(efficiency,"0%") & " Efficiency"             ' dynamic label
```

```excel
W102 = LET(
  shift_time;
  IF(AND(Q6="X";WEEKDAY(E6;2)=2);430; IF(AND(Q6="X";WEEKDAY(E6;2)<>2);440;500));

  downtime_breaks;
  SUMIF($T$14:$V$94;"Break";$K$14:$L$94);

  downtime_no_production;
  SUMIF($T$14:$V$94;"No_Production";$K$14:$L$94);

  planned_downtime;
  planned_downtime - downtime_no_production - downtime_breaks;

  total_downtime;
  downtime_no_production + downtime_breaks + unplanned_downtime + planned_downtime;

  planned_operating_time;
  shift_time - planned_downtime - downtime_no_production - downtime_breaks;

  availability;
  (planned_operating_time - unplanned_downtime) / planned_operating_time;

  performance;
  ((cycle_time_welding/60) * total_produced)/(planned_operating_time - unplanned_downtime);

  quality;
  (total_produced - nok_parts)/total_produced;

  formula_oee;
  IFERROR(quality * performance * availability;0);

  formula_oee
)                                                                       ' OEE Calculation
```

## 7. Downtime Aggregation per Failure Category

```excel
AW2 = SUMIF($T$14:$V$94,$AV2,$I$14:$J$94) + SUMIF($T$14:$V$94,$AV2,$K$14:$L$94)
AX2 = IF(AW2<>0, AV2, "")
AY2 = FILTER(AX2:AX22, AX2:AX22<>"")     ' only categories that actually occurred
```

## 8. VBA Macros (`03.scripts/VBA/`)

- `dataset_macro.bas` - `report_datasets()`: flattens the report into `tbl_failures` and `tbl_status` with `snake_case` headers. Normalization rules applied in VBA:
  - Shift label → `morning` / `afternoon` / `evening` (from checkbox cells)
  - Team leader → `UCase$`
  - Surrogate ID → `workbook name & sheet name`
  - Date → real date value, not the typed string
  - Merged cells → resolved via `.MergeArea.Cells(1,1)`
  - Empty breakdown rows (no planned and no unplanned stoppage) deleted
- `this_workbook_macro.bas` - workbook lifecycle events: `Open`, `BeforeSave`, `BeforeClose`

## Output (what leaves Excel)

`Dataset` (hidden) ends up with two tables:

**`tbl_failures`** - one row per stoppage:
`ID, date, line, schedule, unplanned_stoppages, planned_stoppages, work_station,
equipment, failure_type, sub_code, failure_description`

**`tbl_status`** - one row per shift/line:
`ID, date, line, shift, team_leader, num_operators,total_produced, 
nok_parts, reworked_parts, observations, version, cycle_time`
