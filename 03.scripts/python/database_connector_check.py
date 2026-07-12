'''
Script  :database_connector_check.py
Purpose :Validates the pyodbc connection to the Azure SQL Server instance.
         Run this before executing any ETL pipeline to confirm connectivity.
Usage   :python database_connector_check.py
'''
import pyodbc

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

try:
    conn = pyodbc.connect(connection_string, timeout=10)
    conn.close()
    print("🟢 Connection successful.")
except pyodbc.Error as e:
    print(f"🔴 Connection failed: {e}")
