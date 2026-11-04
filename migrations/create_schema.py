"""Run the archive's initial schema migration from a private managed-identity runner.
Never execute from a public hosted agent or as SQL server administrator.
Requires approved, preinstalled azure-identity, pyodbc and ODBC Driver 18.
"""
import os
import re
import struct

statements = [
    "CREATE TABLE msms_obj_type (obj_type_id INT PRIMARY KEY IDENTITY, obj_type_nm VARCHAR(255) NOT NULL, obj_type_desc VARCHAR(255) NOT NULL, created_dt DATETIME)",
    "CREATE TABLE msms_obj (ms_id INT DEFAULT 0, obj_id INT PRIMARY KEY IDENTITY, obj_type_id INT NOT NULL, obj_nm VARCHAR(255) NOT NULL, created_dt DATETIME, FOREIGN KEY (obj_type_id) REFERENCES msms_obj_type(obj_type_id) ON DELETE CASCADE)",
    "CREATE TABLE msms_mem_obj_type (ms_id INT DEFAULT 0, obj_type_id INT NOT NULL, mem_ms_id INT DEFAULT 0, mem_obj_type_id INT NOT NULL, mem_obj_type_oc INT NOT NULL, mem_obj_type_seq INT NOT NULL, created_dt DATETIME, PRIMARY KEY (obj_type_id, mem_obj_type_id), FOREIGN KEY (obj_type_id) REFERENCES msms_obj_type(obj_type_id) ON DELETE CASCADE, FOREIGN KEY (mem_obj_type_id) REFERENCES msms_obj_type(obj_type_id) ON DELETE NO ACTION)",
    "CREATE TABLE msms_mem_obj (ms_id INT DEFAULT 0, obj_id INT NOT NULL, mem_ms_id INT DEFAULT 0, mem_obj_id INT NOT NULL, mem_obj_seq INT NOT NULL, created_dt DATETIME, PRIMARY KEY (obj_id, mem_obj_id), FOREIGN KEY (obj_id) REFERENCES msms_obj(obj_id) ON DELETE CASCADE, FOREIGN KEY (mem_obj_id) REFERENCES msms_obj(obj_id) ON DELETE NO ACTION)",
    "CREATE TABLE msms_va (va_id INT PRIMARY KEY, va_nm VARCHAR(255) NOT NULL, va_desc VARCHAR(255) NOT NULL, data_type VARCHAR(255) NOT NULL, created_dt DATETIME)",
    "CREATE TABLE msms_val (obj_id INT NOT NULL, va_id INT NOT NULL, val_text VARCHAR(255), val_number INT, val_date DATETIME, val_error VARCHAR(255), val_seq INT NOT NULL, created_dt DATETIME, PRIMARY KEY (obj_id, va_id, val_seq), FOREIGN KEY (obj_id) REFERENCES msms_obj(obj_id) ON DELETE CASCADE, FOREIGN KEY (va_id) REFERENCES msms_va(va_id) ON DELETE CASCADE)",
    "SET IDENTITY_INSERT msms_obj_type ON",
    "INSERT INTO msms_obj_type (obj_type_id, obj_type_nm, obj_type_desc, created_dt) VALUES (0,'MDO','To store MDO',GETDATE()),(1,'MeshEnv','To store MeshEnv',GETDATE()),(2,'MeshReleases','To store MeshReleases',GETDATE()),(3,'MeshInstance','To store MeshInstance',GETDATE()),(4,'MeshSpec','To store MeshSpecs',GETDATE()),(5,'Variable','To store Variable',GETDATE()),(6,'Successors','To store Successors',GETDATE()),(7,'Lineage','To store Lineage',GETDATE()),(8,'Status Tags','To store Status Tags',GETDATE()),(9,'Security Tags','To store Security Tags',GETDATE()),(10,'Access Tags','To store Access Tags',GETDATE()),(11,'User Tags','To store User Tags',GETDATE()),(12,'Date Updated','To store Date Updated',GETDATE()),(13,'Alias','To store Alias',GETDATE()),(14,'Handle','To store Handle',GETDATE())",
    "SET IDENTITY_INSERT msms_obj_type OFF",
    "SET IDENTITY_INSERT msms_obj ON",
    "INSERT INTO msms_obj (ms_id, obj_id, obj_type_id, obj_nm, created_dt) VALUES (0,1,1,?,GETDATE()),(0,2,0,'MDO',GETDATE()),(0,3,6,'Successors',GETDATE()),(0,4,2,'MESH 2.1',GETDATE()),(0,5,0,'MDO',GETDATE()),(0,6,6,'Successors',GETDATE()),(0,7,5,'MeshSpec - Dedicated Cluster',GETDATE()),(0,8,0,'MDO',GETDATE()),(0,9,6,'Successors',GETDATE()),(0,10,5,'MeshSpec - Cluster Size',GETDATE()),(0,11,0,'MDO',GETDATE()),(0,12,6,'Successors',GETDATE()),(0,13,5,'MeshSpec - MDSA Version',GETDATE()),(0,14,0,'MDO',GETDATE()),(0,15,6,'Successors',GETDATE()),(0,16,5,'MeshEnv - Unity Catalog Metastore',GETDATE()),(0,17,0,'MDO',GETDATE()),(0,18,6,'Successors',GETDATE()),(0,19,5,'MeshSpec - Cluster ID',GETDATE()),(0,20,0,'MDO',GETDATE()),(0,21,6,'Successors',GETDATE()),(0,22,5,'MeshSpec - Created By',GETDATE()),(0,23,0,'MDO',GETDATE()),(0,24,6,'Successors',GETDATE()),(0,25,5,'MeshSpec - Content',GETDATE()),(0,26,0,'MDO',GETDATE()),(0,27,6,'Successors',GETDATE()),(0,28,5,'MeshSpec - Mesh Name',GETDATE()),(0,29,0,'MDO',GETDATE()),(0,30,6,'Successors',GETDATE())",
    "SET IDENTITY_INSERT msms_obj OFF",
    "INSERT INTO msms_mem_obj (ms_id, obj_id, mem_ms_id, mem_obj_id, mem_obj_seq, created_dt) VALUES (0,1,0,4,1,GETDATE()),(0,1,0,2,1,GETDATE()),(0,2,0,3,1,GETDATE()),(0,4,0,5,1,GETDATE()),(0,5,0,6,1,GETDATE()),(0,7,0,8,1,GETDATE()),(0,8,0,9,1,GETDATE()),(0,10,0,11,1,GETDATE()),(0,11,0,12,1,GETDATE()),(0,13,0,14,1,GETDATE()),(0,14,0,15,1,GETDATE()),(0,16,0,17,1,GETDATE()),(0,17,0,18,1,GETDATE()),(0,19,0,20,1,GETDATE()),(0,20,0,21,1,GETDATE()),(0,22,0,23,1,GETDATE()),(0,23,0,24,1,GETDATE()),(0,25,0,26,1,GETDATE()),(0,26,0,27,1,GETDATE()),(0,28,0,29,1,GETDATE()),(0,29,0,30,1,GETDATE())",
    "INSERT INTO msms_mem_obj_type (ms_id, obj_type_id, mem_ms_id, mem_obj_type_id, mem_obj_type_oc, mem_obj_type_seq, created_dt) VALUES (0,1,0,2,0,0,GETDATE()),(0,1,0,3,0,0,GETDATE()),(0,1,0,4,0,0,GETDATE()),(0,1,0,0,0,0,GETDATE()),(0,2,0,0,0,0,GETDATE()),(0,3,0,0,0,0,GETDATE()),(0,4,0,0,0,0,GETDATE()),(0,5,0,0,0,0,GETDATE()),(0,6,0,0,0,0,GETDATE()),(0,7,0,0,0,0,GETDATE()),(0,8,0,0,0,0,GETDATE()),(0,9,0,0,0,0,GETDATE()),(0,10,0,0,0,0,GETDATE()),(0,11,0,0,0,0,GETDATE()),(0,12,0,0,0,0,GETDATE()),(0,13,0,0,0,0,GETDATE()),(0,14,0,0,0,0,GETDATE())",
    "INSERT INTO msms_va (va_id, va_nm, va_desc, data_type, created_dt) VALUES (7,'MeshSpec - Dedicated Cluster','Dedicated cluster. Possible values - 0 - no, 1 - yes','int',GETDATE()),(10,'MeshSpec - Cluster Size','Cluster size, in case if Dedicated Cluster - 1. Possible values - Standart / 2x / 4x / 8x','string',GETDATE()),(13,'MeshSpec - MDSA Version','MDSA Version','string',GETDATE()),(16,'MeshEnv - Unity Catalog Metastore','Name of Unity catalog Metastore','string',GETDATE()),(19,'MeshSpec - Cluster ID','ID of Databricks cluster','string',GETDATE()),(22,'MeshSpec - Created By','Username of who crated meshspec','string',GETDATE()),(25,'MeshSpec - Content','MeshSpec content','string',GETDATE()),(28,'MeshSpec - Mesh Name','Name of Mesh for which MeshSpec is created','string',GETDATE())",
    "INSERT INTO msms_val (obj_id, va_id, val_text, val_number, val_date, val_error, val_seq, created_dt) VALUES (1,16,?,NULL,NULL,NULL,1,GETDATE()),(1,19,?,NULL,NULL,NULL,1,GETDATE())",
]


def execute_migration(connection, environment_label, cluster_identifier, metastore_name):
    # Parameters are data, never SQL. One transaction; no duplicate-error suppression.
    cursor = connection.cursor()
    try:
        cursor.execute("SET XACT_ABORT ON")
        cursor.execute("""
            DECLARE @result int;
            EXEC @result = sys.sp_getapplock
              @Resource = 'ad-env-schema-v1', @LockMode = 'Exclusive',
              @LockOwner = 'Transaction', @LockTimeout = 10000;
            IF @result < 0 THROW 51000, 'Migration lock unavailable', 1;
        """)
        cursor.execute("""
            IF OBJECT_ID('dbo.ad_env_schema_version', 'U') IS NULL
              CREATE TABLE dbo.ad_env_schema_version
                (version int NOT NULL PRIMARY KEY, applied_at datetime2 NOT NULL);
        """)
        cursor.execute("SELECT version FROM dbo.ad_env_schema_version WHERE version = ?", 1)
        if cursor.fetchone():
            connection.commit()
            return False
        for statement in statements:
            if "INSERT INTO msms_obj (" in statement:
                cursor.execute(statement, environment_label)
            elif "INSERT INTO msms_val (" in statement:
                cursor.execute(statement, metastore_name, cluster_identifier)
            else:
                cursor.execute(statement)
        cursor.execute("INSERT INTO dbo.ad_env_schema_version VALUES (?, SYSUTCDATETIME())", 1)
        connection.commit()
        return True
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()


def main():
    import pyodbc
    from azure.identity import ManagedIdentityCredential

    server = os.environ["SQL_SERVER_FQDN"]
    database = os.environ["SQL_DATABASE_NAME"]
    if not re.fullmatch(r"[a-z0-9-]+\.database\.windows\.net", server):
        raise ValueError("SQL server must be an Azure SQL hostname")
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,128}", database):
        raise ValueError("Invalid database name")
    # Only the migration identity is given database-specific DDL permission.
    # An access connector identity is NOT automatically a runner identity.
    client_id = os.environ.get("MIGRATION_MANAGED_IDENTITY_CLIENT_ID")
    credential = ManagedIdentityCredential(client_id=client_id) if client_id else ManagedIdentityCredential()
    try:
        raw_token = credential.get_token("https://database.windows.net/.default").token.encode("utf-16-le")
        token = struct.pack("<I", len(raw_token)) + raw_token
        with pyodbc.connect(
            f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER=tcp:{server},1433;"
            f"DATABASE={database};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;",
            attrs_before={1256: token}, autocommit=False,
        ) as connection:
            changed = execute_migration(connection, os.environ["ENVIRONMENT_LABEL"], os.environ["DATABRICKS_CLUSTER_ID"], os.environ["UNITY_CATALOG_METASTORE_NAME"])
            print("Schema version 1 applied." if changed else "Schema version 1 already applied.")
    finally:
        credential.close()


if __name__ == "__main__":
    # Never print SQL statements, tokens, connection strings or driver diagnostics.
    try:
        main()
    except Exception:
        raise SystemExit("Migration failed; transaction rolled back where opened. Investigate in restricted diagnostics.")
