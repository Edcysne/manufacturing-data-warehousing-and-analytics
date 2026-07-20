# =============================================================================
# bulk_insert_data.py
# -----------------------------------------------------------------------------
# Purpose  : One-shot bulk load of historical CSV data into the Azure SQL
#            Bronze Layer, targeting the breakdown_data and
#            status_data tables.
#
# Notes    : I did not use SQL to perform this action due to connection issues.
#            It seems Azure SQL Database does not read files from C: folders.
#            In an Enterprise environment I would do it using SQL for simplitcity,
#            since all files would be in the Azure Cloud.
#
#
# Crucial Mistake: I've loaded everything into the production database without
#                  testing it in a proper dev database. This would be a disaster
#                  in real life.
#
#  Later Improvements: Learn more about error handling and dry-runs
#
# =============================================================================
import os
import pandas as pd
import pyodbc

# --- CONNECTION VARIABLES ---
server       = '<your-server>.database.windows.net'
driver       = 'ODBC Driver 18 for SQL Server'
server_admin = '<db-admin-user>'
password     = '<your-password>'
database     = '<your-database>'

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
CSV_FOLDER     = r'<path-to-bulk-insert-data-folder>'
BREAKDOWN_FILE = os.path.join(CSV_FOLDER, 'breakdown_data.csv')
STATUS_FILE    = os.path.join(CSV_FOLDER, 'status_data.csv')


def _clean(x):
    if isinstance(x, float) and x != x:
        return None
    try:
        if pd.isna(x):
            return None
    except (TypeError, ValueError):
        pass
    return x


# --- BREAKDOWN ---
breakdown_df = pd.read_csv(BREAKDOWN_FILE, dayfirst=True, parse_dates=['date'])
breakdown_df['date']     = breakdown_df['date'].dt.date
breakdown_df['schedule'] = pd.to_datetime(
    breakdown_df['schedule'], format='%H:%M', errors='coerce'
).dt.time
breakdown_df['ID'] = [
    f"{row_id}_{i + 1}" for i, row_id in enumerate(breakdown_df['ID'])
]

# --- STATUS ---
status_df = pd.read_csv(STATUS_FILE, dayfirst=True, parse_dates=['date'])
status_df['date'] = status_df['date'].dt.date
status_df['ID'] = [
    f"{row_id}_{i + 1}" for i, row_id in enumerate(status_df['ID'])
]

# --- INSERT ---
conn   = pyodbc.connect(connection_string)
cursor = conn.cursor()

BD_SQL = """
    INSERT INTO bronze_layer.breakdown_data
        (ID, date, line, schedule, unplanned_stoppages, planned_stoppages,
         work_station, equipment, failure_type, sub_code, failure_description)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

ST_SQL = """
    INSERT INTO bronze_layer.status_data
        (ID, date, line, shift, team_leader, num_operators,
         total_expected_output, total_produced, nok_parts, reworked_parts,
         accidents, near_misses, customer_complaints, observations, version, cycle_time)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

try:
    for i, (_, row) in enumerate(breakdown_df.iterrows(), 1):
        print(f"\r  Breakdown: {i}/{len(breakdown_df)}", end="", flush=True) #Check how many rows are being processed
        cursor.execute(BD_SQL, (
            _clean(row['ID']),
            _clean(row['date']),
            _clean(row['line']),
            _clean(row['schedule']),
            _clean(row.get('unplanned_stoppages')),
            _clean(row.get('planned_stoppages')),
            _clean(row.get('work_station')),
            _clean(row.get('equipment')),
            _clean(row.get('failure_type')),
            _clean(row.get('sub_code')),
            _clean(row.get('failure_description')),
        ))

    print()
    for i, (_, row) in enumerate(status_df.iterrows(), 1):
        print(f"\r  Status: {i}/{len(status_df)}", end="", flush=True)
        cursor.execute(ST_SQL, (
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

    print()
    conn.commit()
    print(f"✅ Inserted {len(breakdown_df):,} breakdown rows | {len(status_df):,} status rows")

except Exception as e:
    conn.rollback()
    print(f"🔴 Insert failed - transaction rolled back.\n   {e}")

finally:
    cursor.close()
    conn.close()
