# =============================================================================
# LOMPSTAR MANUFACTURING -> Extract & Load (EL) PIPELINE
# =============================================================================
# Description  : Extracts production summary data from .xlsm files generated
#                by Team Leaders and loads it into the Azure SQL Database.
#
# Workflow     : 1. Scans the current month's subfolder for .xlsm files
#                2. Checks the file_log table for already processed files
#                3. Skips files that were previously loaded (avoid duplicates)
#                4. Loads new files into the Bronze Layer:
#                     - wel_breakdown_data  (stoppage / failure records)
#                     - wel_status_data     (shift KPI summary)
#                5. Logs every processed file in file_log (success or error)
#
# Source       : Team Leader Production Summaries (.xlsm) — Sheet: "Dataset"
# Destination  : Azure SQL Database -> Bronze Layer
#
# Author       : Eduardo Cysne
# Created      : 20/04/2026
# Last Updated : 27/04/2026
# Version      : 1.1
#
# !!! SCHEMA FIX REQUIRED before first run !!!
# The work_station column was defined as DECIMAL(2,2) but the actual data is a
# string code (e.g. 'AS_320', 'FT_330'). Run this once in Azure SQL:
#
#   ALTER TABLE bronze_layer.wel_breakdown_data
#       ALTER COLUMN work_station VARCHAR(50);
#
# =============================================================================

from datetime import datetime
import openpyxl
import pandas as pd
import pyodbc
import uuid
import os

# --- CONNECTION VARIABLES ---
server       = 'manufacturing-warehouse.database.windows.net'
driver       = 'ODBC Driver 18 for SQL Server'
server_admin = 'warehousing-admin'
password     = 'safe-password123'
database     = 'db-warehousing'

connection_string = (
    f"Driver={{{driver}}};"
    f"Server={server};"
    f"Database={database};"
    f"UID={server_admin};"
    f"PWD={password};"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
)

# --- PATHS ---
EXCEL_FOLDER = (
    r'C:\Users\amcys\Documents\02.Education\01.Online Education'
    r'\05.projects\data-warehousing\01.Reports\Production Reports'
)

TODAY        = datetime.today()
YEAR         = TODAY.strftime('%Y')
MONTH_NUM    = TODAY.strftime('%m')
MONTH_STR    = TODAY.strftime('%b')
MONTH_FOLDER = f"{MONTH_NUM}. {MONTH_STR} {YEAR}"
SUBFOLDER    = os.path.join(EXCEL_FOLDER, YEAR, MONTH_FOLDER)


# =============================================================================
# HELPERS
# =============================================================================
def _clean(value):
    """Convert float NaN (pandas default for missing cells) to None for SQL."""
    if isinstance(value, float) and value != value:  # NaN != NaN is always True
        return None
    return value


def get_db_connection(autocommit: bool = False) -> pyodbc.Connection:
    conn = pyodbc.connect(connection_string)
    conn.autocommit = autocommit
    return conn


def get_processed_files(cursor: pyodbc.Cursor) -> set:
    """Return the set of file names already successfully loaded."""
    cursor.execute(
        "SELECT file_name FROM bronze_layer.wel_file_log WHERE status = 'success'"
    )
    return {row[0] for row in cursor.fetchall()}


# =============================================================================
# EXTRACT
# =============================================================================

def extract_file_data(file_path: str):
    """
    Open the 'Dataset' sheet and return (breakdown_df, status_df).

    Sheet layout written by VBA:
      Row 1         -> Breakdown headers  (11 columns)
      Rows 2+       -> Breakdown data rows
      Empty row     -> Separator
      Next row      -> Status headers  (16 columns)
      Row(s) after  -> Status data

    The VBA generates the same ID for every breakdown row of a file+line,
    so we append a 1-based index (_1, _2, ...) to guarantee uniqueness.
    """
    wb = openpyxl.load_workbook(file_path, read_only=True, keep_vba=True)
    ws = wb['Dataset']
    rows = list(ws.iter_rows(values_only=True))
    wb.close()

    # Find the empty separator row between the two datasets
    separator = None
    for i in range(1, len(rows)):
        if not any(v is not None for v in rows[i]):
            separator = i
            break

    if separator is None:
        raise ValueError(
            "Dataset sheet is missing the empty separator row "
            "between the breakdown and status datasets."
        )

    # --- Breakdown DataFrame ---
    bd_headers   = [c for c in rows[0] if c is not None]
    bd_data      = [list(r[:len(bd_headers)]) for r in rows[1:separator]]
    breakdown_df = pd.DataFrame(bd_data, columns=bd_headers)

    # Make every breakdown ID unique (VBA bug: same ID across all breakdown rows)
    breakdown_df['ID'] = [
        f"{row_id}_{i + 1}" for i, row_id in enumerate(breakdown_df['ID'])
    ]

    # datetime.datetime -> date (SQL DATE column)
    breakdown_df['date'] = breakdown_df['date'].apply(
        lambda d: d.date() if isinstance(d, datetime) else d
    )

    # --- Status DataFrame ---
    st_headers = [c for c in rows[separator + 1] if c is not None]
    st_data    = [
        list(r[:len(st_headers)])
        for r in rows[separator + 2:]
        if any(v is not None for v in r)
    ]
    status_df = pd.DataFrame(st_data, columns=st_headers)

    status_df['date'] = status_df['date'].apply(
        lambda d: d.date() if isinstance(d, datetime) else d
    )

    return breakdown_df, status_df


# =============================================================================
# LOAD
# =============================================================================

def insert_breakdown(cursor: pyodbc.Cursor, df: pd.DataFrame) -> None:
    sql = """
        INSERT INTO bronze_layer.wel_breakdown_data
            (ID, date, line, Schedule, unplanned_stoppages, planned_stoppages,
             work_station, equipment, failure_type, sub_code, failure_description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    for _, row in df.iterrows():
        cursor.execute(sql, (
            _clean(row['ID']),
            _clean(row['date']),
            _clean(row['line']),
            _clean(row['schedule']),          # datetime.time -> TIME(0)
            _clean(row.get('unplanned_stoppages')),
            _clean(row.get('planned_stoppages')),
            _clean(row.get('work_station')),  # VARCHAR(50) — requires schema fix
            _clean(row.get('equipment')),
            _clean(row.get('failure_type')),
            _clean(row.get('sub_code')),
            _clean(row.get('failure_description')),
        ))


def insert_status(cursor: pyodbc.Cursor, df: pd.DataFrame) -> None:
    sql = """
        INSERT INTO bronze_layer.wel_status_data
            (ID, date, line, shift, team_leader, num_operators,
             total_expected_output, total_produced, nok_parts, reworked_parts,
             accidents, near_misses, customer_complaints,
             observations, version, cycle_time)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    for _, row in df.iterrows():
        cursor.execute(sql, (
            _clean(row['ID']),
            _clean(row['date']),
            _clean(row['line']),
            _clean(row.get('shift')),
            _clean(row.get('team_leader')),
            _clean(row.get('num_operators')),
            _clean(row.get('total_expected_output')),
            _clean(row.get('total_produced')),
            _clean(row.get('nok_parts')),
            _clean(row.get('reworked_parts')),
            _clean(row.get('accidents')),
            _clean(row.get('near_misses')),
            _clean(row.get('customer_complaints')),
            _clean(row.get('observations')),
            _clean(row.get('version')),
            _clean(row.get('cycle_time')),
        ))


def log_file(file_name: str, status: str) -> None:
    """
    Writes to file_log using its own autocommit connection so that error
    entries are persisted even after the main transaction is rolled back.
    """
    try:
        conn = get_db_connection(autocommit=True)
        conn.execute(
            "INSERT INTO bronze_layer.wel_file_log (ID, file_name, status) "
            "VALUES (?, ?, ?)",
            (str(uuid.uuid4()), file_name, status)
        )
        conn.close()
    except pyodbc.Error as e:
        print(f"  ⚠️  Could not write to file_log: {e}")


# =============================================================================
# MAIN PIPELINE
# =============================================================================

def run_pipeline() -> None:

    # 1. Validate subfolder
    print(f"📁 Target folder : {SUBFOLDER}")
    if not os.path.exists(SUBFOLDER):
        print("🔴 Subfolder not found. Exiting.")
        return
    print("🟢 Subfolder found.")

    # 2. Connect to database
    try:
        conn   = get_db_connection(autocommit=False)
        cursor = conn.cursor()
        print("🟢 Connected to database.")
    except pyodbc.Error as e:
        print(f"🔴 Connection failed: {e}")
        return

    # 3. Discover .xlsm files and filter out already-loaded ones
    processed = get_processed_files(cursor)
    all_files = sorted(f for f in os.listdir(SUBFOLDER) if f.endswith('.xlsm'))
    new_files = [f for f in all_files if f not in processed]

    print(f"\n📂 Files in folder : {len(all_files)}")
    print(f"   Already loaded  : {len(processed)}")
    print(f"   To process      : {len(new_files)}")

    if not new_files:
        print("\n✅ Nothing new to load.")
        cursor.close()
        conn.close()
        return

    # 4. Process each new file
    success_count = 0
    error_count   = 0

    for file_name in new_files:
        file_path = os.path.join(SUBFOLDER, file_name)
        print(f"\n  ⏳ {file_name}")

        try:
            breakdown_df, status_df = extract_file_data(file_path)
            insert_breakdown(cursor, breakdown_df)
            insert_status(cursor, status_df)
            conn.commit()
            log_file(file_name, 'success')
            success_count += 1
            print(
                f"  🟢 Loaded — "
                f"{len(breakdown_df)} breakdown row(s) | "
                f"{len(status_df)} status row(s)"
            )

        except Exception as e:
            conn.rollback()
            log_file(file_name, 'error')
            error_count += 1
            print(f"  🔴 Failed: {e}")

    cursor.close()
    conn.close()

    print(f"\n{'=' * 50}")
    print(f"Pipeline complete — {success_count} loaded | {error_count} errors")
    print(f"{'=' * 50}")


# --- ENTRY POINT ---
if __name__ == '__main__':
    run_pipeline()
