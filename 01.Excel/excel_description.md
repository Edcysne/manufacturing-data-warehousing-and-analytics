# Phase 1 - Excel Standardization (Summary Generator)

This document explains everything that was built inside the Excel layer of the
project: the **Summary Generator** workbook (`01.reports/Report Generator.xlsb`),
the production reports it generates (`01.reports/Production Reports/.../*.xlsm`),
the **data-normalization logic implemented with Excel formulas**, and the
reasoning behind documenting this phase mainly with **screenshots** instead of
committing the workbooks themselves.

> **Why this phase exists.** The company (LOMPSTAR) tracked production performance
> in inconsistent, manually-filled `.xlsx` files with no validation, no macros and
> no storage. Phase 1 replaces that with a single, controlled template that
> *enforces* how data is entered, so that everything downstream (Python EL → Azure
> SQL Bronze/Silver/Gold → Power BI) receives clean, predictable input. See
> `project_description.md` §1.6 Step 1 for the business framing.

---

## 1. The two files involved

| File | Format | Role |
|------|--------|------|
| `Report Generator.xlsb` | Binary macro workbook | The master template. Team Leaders open it, fill the **Central Panel**, and click a button to spin off a production report. |
| `DDMMYYYY Shift X.xlsm` | Macro-enabled (OOXML) | One output file per shift/day, stored under `Production Reports/<year>/<month>/`. Holds one or more `CTRL *` report sheets plus a hidden `Dataset` sheet. |

The `.xlsb` was chosen for the master because it loads faster and is more compact
for a heavily-formula'd, multi-sheet template; the generated reports are `.xlsm`
so they remain macro-enabled but readable by the Python EL pipeline.

### Sheet inventory (generated report)

- `Block Screen` - landing/lock sheet shown when the file is reopened.
- `Add Report` - the Central Panel after the first report is generated (renamed and partly locked).
- `Ship 1` / `Ship 2` / `Ship 3` - facility maps / reference.
- `Correlations Tables`, `Report Data` - backing tables for dropdowns and cycle times with truth tables logic.
- `Report Layout 1 (WEL)` - the template that gets copied for each new `CTRL *` sheet.
- `CTRL <PART> <CAR> <VERSION> <LINE>` - one per produced product (the actual filled report).
- `Dataset` - **hidden**, machine-generated tabular output (see §4).

---

## 2. How a report is created (VBA flow)

The macros are exported as text under `03.scripts/VBA/` so they *can* be
version-controlled and diffed:

- `generate_report_macro.bas` - `generate_report()` and its branches.
- `dataset_macro.bas` - `report_datasets()` (builds the tabular output).
- `this_workbook_macro.bas` - workbook lifecycle (`Open`, `BeforeSave`, `BeforeClose`).

**Flow:**

1. The Team Leader fills the **Central Panel** (date, team, team leader, shift,
   car, part, version, spare, line). These fields are dropdown-driven.
2. A status cell only turns **"OK"** when the panel is valid; `generate_report()`
   refuses to run otherwise.
3. **Branch A (first report of the day):** the workbook is saved as a new
   `.xlsm` on the network using the convention `DDMMYYYY Shift X`, the Central
   Panel is renamed to `Add Report`, the identity fields are locked, and a
   `CTRL *` sheet is created from the layout template.
4. **Branch B (additional report):** if a `CTRL *` sheet already exists, a new
   `CTRL *` sheet is just appended to the current file - no new file.
5. Each `CTRL *` sheet name is built from the product metadata, uppercased and
   truncated to Excel's 31-character sheet-name limit.
6. On **save and on close**, `report_datasets()` rebuilds the hidden `Dataset`
   sheet so the structured output is always current - even if a Team Leader
   forgets to click anything.

Workbook protection (`x_password`) and `xlSheetVeryHidden` visibility are used
throughout to stop users from breaking the template or seeing the machinery.

---

## 3. Data normalization done with Excel formulas

This is the heart of Phase 1. The goal is **garbage-in prevention**: a Team
Leader should not be *able* to type a free-text station name, an out-of-range
quantity, or a failure code that doesn't belong to the selected machine.
Normalization happens in two places - **input-time** (data validation +
cascading dropdowns) and **calculation-time** (KPI formulas).

### 3.1 Cascading, self-referencing dropdowns (the key mechanism)

Every important cell is a **list** validation whose source is computed by a
formula, so the available options *depend on earlier selections*. Pulled
directly from the report sheet (`Report Layout 1 (WEL)` / `CTRL *`):

| Cell range | Validation source | Effect |
|------------|-------------------|--------|
| `N14:P94` (work station) | `INDIRECT($Z$2 & "working_stations")` | Station list is resolved from a normalized table name built from the product label. |
| `Q14:S94`, `W14:Y94` (equipment / failure) | `INDIRECT(N14)` | The equipment/failure list depends on the **work station** chosen on the same row. |
| `T..:V..` (breakdown analysis) | `breakdown_dropdown` (= `breakdown_analysis[]` table) | Failure typology constrained to a managed table. |
| `G101:L115` (KPI / team rows) | `INDIRECT($Z$4)` | List resolved from the normalized team-leader key. |
| `E5` (date) | `type="date", >= 41275` | Rejects anything that isn't a valid date ≥ 01/01/2013. |
| `G14 … G89` (parts produced/hour) | `type="decimal", >= 0` | Rejects negative or non-numeric production counts. |

The `INDIRECT(...)` pattern is what makes the dropdowns *cascade*: instead of one
giant static list, the formula rebuilds a table/range name on the fly from a
normalized key, so each cell only offers values that are valid in context.

### 3.2 Building the normalized lookup key (`Z2`)

```excel
Z2 = SUBSTITUTE( SUBSTITUTE( LOWER(AH2), " ", "_" ) & "_", "-", "" )
```

`AH2` is the human-readable product + line label (e.g. *"Rear Bumper Line 1 A"*).
The formula lowercases it, replaces spaces with underscores and strips hyphens,
producing a machine key like `rear_bumper_line_1_a_` that is then concatenated
with `"working_stations"` to point `INDIRECT` at the correct backing table.

### 3.3 Accent / diacritic normalization (`Z4`)

Team-leader names contain Portuguese/Spanish accents (João, Inês, Sérgio…). To
turn a display name into a safe, ASCII, lowercase key the workbook uses a nested
`SUBSTITUTE` chain:

```excel
Z4 = LOWER(
       SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(
       SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(
       SUBSTITUTE( Z5, " ", "_"),
       "ã","a"),"â","a"),"á","a"),"à","a"),"ä","a"),"ç","c"),
       "é","e"),"ê","e"),"í","i"),"ó","o"),"ô","o"),"ú","u")
     ) & "_" & "equipa"
```

This is a textbook example of **normalization with pure Excel formulas**: spaces →
underscores, every accented character mapped to its ASCII equivalent, lowercased,
suffixed - yielding a stable key (`ana_sofia_martins_equipa`) usable by
`INDIRECT` and by the downstream pipeline regardless of how the name is typed.

### 3.4 Time grid built by formula, not by hand

The hourly production grid is generated from the shift checkboxes
(`Q5`=evening, `R5`=morning, `S5`=afternoon) so the start time and the legal
breaks are never entered manually:

```excel
C14  = IF($Q$5="X", IF(WEEKDAY($E$5)=2, TIME(0,0,0), TIME(23,50,0)),
        IF($R$5="X", TIME(7,10,0),
        IF($S$5="X", TIME(15,30,0), "")))
C18  = IFERROR(TIME(HOUR(C14)+1, 0, 0), "")        ' each row = +1 hour
K32  = IF(Q5="X",10, IF(R5="X",10, IF(S5="X",10,0))) ' scheduled break minutes
M14  = IF(K14+I14=0, "", K14+I14)                    ' downtime per slot, blank if zero
```

Because the schedule is derived, two reports for the same shift always have the
same time skeleton - essential for comparing OEE across shifts later.

### 3.5 KPI / OEE formulas

OEE = **Availability × Performance × Quality**. The components are computed from
named ranges that point at fixed cells in the layout:

| Named range | Cell | Meaning |
|-------------|------|---------|
| `total_produced` | `G93` | `=SUM` of every hourly production slot |
| `nok_parts` | `Q99` | non-conforming parts |
| `reworked_parts` | `W99` | reworked parts |
| `planned_downtime` | `K95` | `=SUM(K14:L94)` |
| `unplanned_downtime` | `I95` | `=SUM(I14:J94)` |
| `efficiency` | `W108` | target efficiency |
| `cycle_time_welding` | `W111` | resolved cycle time |
| `number_workers` | `Q102` | operators on the line |

Representative formulas:

```excel
Q105 = IFERROR( IF(total_produced>0, nok_parts/total_produced, 0), 0)     ' NOK rate
Q108 = IFERROR( (total_produced - reworked_parts) / total_produced, 0)    ' Quality
Q111 = IF(total_produced=0, 0,
         unplanned_downtime + planned_downtime
         - SUMIF($T$14:$V$94,"No_Production",$M$14:$M$94))                ' net downtime
W111 = IFERROR( INDIRECT(nome_kpis_sol1 & "cycle_time"), "-")            ' cycle time lookup
E7   = "Goal With " & TEXT(efficiency,"0%") & " Efficiency"             ' dynamic label
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
)                                                                       'OEE Calculation
```

The downtime aggregation per failure category uses `SUMIF` over the breakdown
grid:

```excel
AW2 = SUMIF($T$14:$V$94,$AV2,$I$14:$J$94) + SUMIF($T$14:$V$94,$AV2,$K$14:$L$94)
AX2 = IF(AW2<>0, AV2, "")
AY2 = FILTER(AX2:AX22, AX2:AX22<>"")     ' only categories that actually occurred
```

### 3.6 Normalization completed by the dataset macro

Formulas standardize *input*; the `report_datasets()` macro standardizes the
*shape* of the output. It flattens the visual report into two clean tables with
`snake_case` headers, and applies its own normalization rules:

- **Shift label** → `morning` / `afternoon` / `evening` (from the checkbox cells).
- **Team leader** → `UCase$` for a consistent casing.
- **Surrogate ID** → `workbook name & sheet name` (unique per product/day/shift).
- **Date** → real date value, not the typed string.
- **Merged cells** → resolved to a single value via `.MergeArea.Cells(1,1)`.
- **Empty rows dropped** - breakdown rows with no planned *and* no unplanned
  stoppage are deleted, so only real events survive.

The two output tables (`tbl_falhas`/`tbl_failures` and `tbl_status`) are exactly
the contract the Python EL step expects - this is the "first transformation" the
project description says is done in Excel rather than in SQL.

> **Known data-fidelity caveat** (see `mistakes.md`, 2nd mistake): the source
> system (Nemetris) stores breakdown minutes as decimals, but the Excel export
> truncates them to integers. The normalization here cannot recover that lost
> precision; it is documented as a known limitation rather than silently ignored.

---

## 4. Output contract (what leaves Excel)

`Dataset` (hidden) ends up with two tables:

**`tbl_failures`** - one row per stoppage:
`ID, date, line, schedule, unplanned_stoppages, planned_stoppages, work_station,
equipment, failure_type, sub_code, failure_description`

**`tbl_status`** - one row per shift/line:
`ID, date, line, shift, team_leader, num_operators, total_expected_output,
total_produced, nok_parts, reworked_parts, accidents, near_misses,
customer_complaints, observations, version, cycle_time`

These map 1:1 to the Bronze-layer tables `wel_breakdown_data` and
`wel_status_data` (`03.scripts/sql/02.bronze_layer_tables.sql`).

---

## 5. Why this phase is documented with screenshots

The decision to document the Excel work primarily through **screenshots** (plus
the exported `.bas` macros) is deliberate, not a shortcut. The driving reason is
**compliance**:

1. **The binary workbooks can contain critical / sensitive data - so they are
   never committed.** A filled `.xlsb`/`.xlsm` holds real production figures,
   internal cycle times, OEE performance, named team leaders and other
   operational data that must not be published to the repository (or to any
   external service the repo touches). Committing the binaries would leak that
   data into Git history permanently, where it cannot be cleanly removed. Keeping
   the workbooks **out of version control** and documenting them with redacted /
   illustrative screenshots is the only way to share *how the system works*
   without exposing *the data it carries*. This is the primary reason for the
   screenshot approach.

2. **The workbooks are binary blobs to Git anyway.** `.xlsb` is a binary format
   and `.xlsm` is a zipped OOXML bundle. Even setting compliance aside, Git
   cannot produce a meaningful diff of either - a one-cell change shows up as
   "binary file changed", giving no reviewable history, only large opaque
   revisions.

3. **The real logic lives *inside cells*, not in source files.** Validation
   rules, `INDIRECT` dropdown sources, conditional formatting, named ranges and
   the OEE formulas are properties of cells. There is no plain-text "source code"
   for a worksheet the way there is for the VBA, so the only faithful, at-a-glance
   record of *"what the user sees and is allowed to do"* is an image.

4. **Most of the value is visual / behavioural.** The standardization is about
   layout, locked regions, the green "OK" gating, cascading dropdowns and the
   button-driven workflow. A screenshot communicates that instantly; a cell dump
   would not.

5. **What *can* be text, *is* text.** The genuinely diff-able, logic-bearing part
   - the VBA - is exported to `03.scripts/VBA/*.bas` and version-controlled
   properly (and carries no production data). Screenshots cover only the parts
   Git can't represent safely or usefully.

> In short: the **binaries stay out of the repo for compliance** (they can hold
> critical data), the **macros are documented as code** (`.bas`, data-free), and
> the **worksheet UI, validation and formulas are documented as screenshots** -
> the only medium that conveys the design without leaking the data.

### Suggested screenshot set

Place images under `02.images/png - jpg/excel/` and reference them here. Use
**dummy / redacted data** in any shot - the point is to show the mechanism, not
real production figures or named personnel:

- Central Panel with the dropdowns and the green **OK** status.
- A filled `CTRL *` report showing the hourly grid and KPI block.
- A data-validation dialog showing an `INDIRECT(...)` list source.
- The hidden `Dataset` sheet with `tbl_failures` and `tbl_status`.
- The "Generate Report / Add Report / Delete Report" buttons in context.
