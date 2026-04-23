# =============================================================================
# LOMPSTAR MANUFACTURING -> Extract & Load (EL) PIPELINE
# =============================================================================
# Description  : Extracts production summary data from .xlsm files generated
#                by Team Leaders and loads it into the Azure SQL Database.
#
# Workflow     : 1. Scans the designated folder for .xlsm files
#                2. Checks the file_log table for already processed files
#                3. Skips files that were previously loaded (avoid duplicates)
#                4. Loads new files into the Bronze Layer (production_summary)
#                5. Logs every processed file in file_log (success or error)
#
# Source       : Team Leader Production Summaries (.xlsm)
# Destination  : Azure SQL Database -> Bronze Layer
#
# Author       : Eduardo Cysne
# Created      : 20/04/2026
# Last Updated : 20/04/2026
# Version      : 1.0
# =============================================================================

# Libraries Importation
import pandas as pd
import pyodbc
import os

# --- CONNECTION VARIABLES ---
server       = 'manufacturing-warehouse.database.windows.net'
driver       = 'ODBC Driver 18 for SQL Server'
server_admin = 'warehousing-admin'
password     = 'safe-password123'
database     = 'db-warehousing'

# --- CONNECTION STRING ---
connection_string = (
    f"Driver={{{driver}}};"
    f"Server={server};"
    f"Database={database};"
    f"UID={server_admin};"
    f"PWD={password};"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
)

# --- VERIFY STRING BEFORE CONNECTING ---
print(connection_string)

# --- TEST CONNECTION ---
try:
    pyodbc.connect(connection_string)
    print("✅ Successful Connection")

except pyodbc.Error as e:
    print("❌ Error on Connection to the database")
    print(f"{e}")

