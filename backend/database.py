import sqlite3
import json
import os
from pathlib import Path
from datetime import datetime

DB_DIR = Path(__file__).resolve().parent / "data"
DB_PATH = DB_DIR / "ad.db"

def get_connection():
    DB_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    return conn

def init_db():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        email TEXT PRIMARY KEY,
        name TEXT,
        password TEXT,
        role TEXT,
        account_id TEXT,
        access TEXT DEFAULT '{"catalogs":[]}',
        created_at TEXT
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        name TEXT,
        solution TEXT,
        region TEXT,
        env TEXT,
        tenancy TEXT,
        management TEXT,
        status TEXT,
        data TEXT,
        created_at TEXT
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        account_id TEXT,
        kind TEXT,
        source TEXT,
        requested_by TEXT,
        status TEXT,
        data TEXT,
        created_at TEXT
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS work_orders (
        id TEXT PRIMARY KEY,
        account_id TEXT,
        by_user TEXT,
        verb TEXT,
        text TEXT,
        status TEXT,
        result TEXT,
        metrics TEXT DEFAULT '[]',
        promoted INTEGER DEFAULT 0,
        created_at TEXT
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        actor TEXT,
        action TEXT,
        ref TEXT
    );
    """)

    # Lightweight schema migrations for existing DB files
    u_cols = {r[1] for r in cursor.execute("PRAGMA table_info(users);").fetchall()}
    if "access" not in u_cols:
        cursor.execute("ALTER TABLE users ADD COLUMN access TEXT DEFAULT '{\"catalogs\":[]}';")
    wo_cols = {r[1] for r in cursor.execute("PRAGMA table_info(work_orders);").fetchall()}
    if "metrics" not in wo_cols:
        cursor.execute("ALTER TABLE work_orders ADD COLUMN metrics TEXT DEFAULT '[]';")
    if "promoted" not in wo_cols:
        cursor.execute("ALTER TABLE work_orders ADD COLUMN promoted INTEGER DEFAULT 0;")

    conn.commit()

    # Seed initial data if users table is empty
    cursor.execute("SELECT COUNT(*) FROM users;")
    if cursor.fetchone()[0] == 0:
        seed_db(conn)
    else:
        # Ensure primary Alida staff admin exists even on persisted volumes
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
        cursor.execute("""
        INSERT OR IGNORE INTO users (email, name, password, role, account_id, access, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """, ("demetrius@alidainc.com", "Demetrius", "ad", "staff", None, '{"catalogs":[]}', now_str))
        conn.commit()

    conn.close()

def seed_db(conn):
    cursor = conn.cursor()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M")

    # Default Seed Users (Alida staff are Admins; client users are Operators only)
    users = [
        ("demetrius@alidainc.com", "Demetrius", "ad", "staff", None, json.dumps({"catalogs": []}), now_str),
        ("staff@alidainc.com", "Alida staff", "ad", "staff", None, json.dumps({"catalogs": []}), now_str),
        ("bill@alidainc.com", "Bill Sequeira", "ad", "user", "alida-internal", json.dumps({"catalogs": ["gendf", "readygo-retail"]}), now_str),
        ("dhananjay@alidainc.com", "Dhananjay Goel", "ad", "user", "alida-internal", json.dumps({"catalogs": ["readygo-retail"]}), now_str),
        ("maya@mercy.org", "Maya Chen", "ad", "user", "mercy-clinics", json.dumps({"catalogs": ["gendf"]}), now_str),
        ("raj@mercy.org", "Raj Patel", "ad", "user", "mercy-clinics", json.dumps({"catalogs": ["gendf"]}), now_str)
    ]
    cursor.executemany("""
    INSERT INTO users (email, name, password, role, account_id, access, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    """, users)

    # Default Seed Accounts (100% Dedicated single-tenant environments)
    accounts = [
        (
            "alida-internal", "Alida Internal (first client)", "data-foundation", "eastus2", "dev1", "dedicated", "fully", "ready",
            json.dumps({
                "domains": ["gendf", "readygo-retail"],
                "resources": {"spendLimitUsd": 5000, "storageGb": 500},
                "usage": {"spendUsd": 1840, "computeHours": 62},
                "datasets": [
                    {"name": "retail_orders_2025", "gb": 12.4, "src": "UC"},
                    {"name": "store_master", "gb": 0.3, "src": "import"}
                ]
            }),
            "2026-11-20"
        ),
        (
            "mercy-clinics", "Mercy Clinics", "data-foundation", "eastus2", "prod1", "dedicated", "fully", "ready",
            json.dumps({
                "domains": ["gendf"],
                "resources": {"spendLimitUsd": 12000, "storageGb": 1000},
                "usage": {"spendUsd": 3100, "computeHours": 90},
                "datasets": [
                    {"name": "encounters_2025", "gb": 40.2, "src": "import"}
                ]
            }),
            "2026-11-22"
        )
    ]
    cursor.executemany("""
    INSERT INTO accounts (id, name, solution, region, env, tenancy, management, status, data, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, accounts)

    # Default Seed Orders
    co_data = {
        "validation": {"ok": True, "errors": [], "warnings": []},
        "changes": [
            {"op": "provision", "target": "environment", "value": "eastus2 · dedicated · fully managed"},
            {"op": "add", "target": "domain", "id": "gendf"},
            {"op": "add", "target": "domain", "id": "readygo-retail"},
            {"op": "add", "target": "user", "email": "bill@alidainc.com"},
            {"op": "set", "target": "access", "email": "bill@alidainc.com", "catalogs": ["gendf", "readygo-retail"]}
        ],
        "jobs": [
            ["Check the order", "done"],
            ["Create dedicated environment", "done"],
            ["Create dedicated database", "done"],
            ["Create dedicated compute", "done"],
            ["Configure services", "done"],
            ["Start AD", "done"],
            ["Verify", "done"]
        ]
    }
    cursor.execute("""
    INSERT INTO orders (id, account_id, kind, source, requested_by, status, data, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        "CO-0001", "alida-internal", "provision", "staff", "demetrius@alidainc.com", "applied",
        json.dumps(co_data), "2026-11-20 09:12"
    ))

    # Default Work Orders
    cursor.execute("""
    INSERT INTO work_orders (id, account_id, by_user, verb, text, status, result, metrics, promoted, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        "WO-0001", "alida-internal", "dhananjay@alidainc.com", "PRODUCE",
        "Produce a data foundation from retail_orders_2025", "done",
        "2 datasets integrated into one foundation.",
        json.dumps([["Rows", "1.2M"], ["Entities", "14"], ["Transformations", "38"], ["Quality", "98%"], ["Time", "3m 20s"]]),
        0,
        now_str
    ))

    # Default Audit Logs
    audit = [
        ("2026-11-20 09:31", "orchestrator", "config-order.applied", "CO-0001"),
        ("2026-11-20 09:14", "demetrius@alidainc.com", "sales-order.received", "SO-0001")
    ]
    cursor.executemany("""
    INSERT INTO audit_logs (timestamp, actor, action, ref)
    VALUES (?, ?, ?, ?)
    """, audit)

    conn.commit()

# --- Users ---
def _parse_user(row):
    u = dict(row)
    u["accountId"] = u.get("account_id")
    raw_acc = u.get("access")
    if isinstance(raw_acc, str):
        try:
            u["access"] = json.loads(raw_acc)
        except Exception:
            u["access"] = {"catalogs": []}
    elif not isinstance(raw_acc, dict):
        u["access"] = {"catalogs": []}
    return u

def get_user(email: str):
    conn = get_connection()
    row = conn.execute("SELECT * FROM users WHERE email = ? COLLATE NOCASE", (email.strip(),)).fetchone()
    conn.close()
    if row:
        return _parse_user(row)
    return None

def authenticate_user(email: str, password: str):
    user = get_user(email)
    if user and user["password"] == password:
        return user
    return None

def create_user(email: str, name: str, password: str, role: str = "user", account_id: str = None, access: dict = None):
    conn = get_connection()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    access_json = json.dumps(access if isinstance(access, dict) else {"catalogs": []})
    try:
        conn.execute("""
        INSERT INTO users (email, name, password, role, account_id, access, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(email) DO UPDATE SET
            name = excluded.name,
            password = CASE WHEN excluded.password IS NOT NULL AND excluded.password != 'welcome' THEN excluded.password ELSE users.password END,
            role = excluded.role,
            account_id = COALESCE(excluded.account_id, users.account_id),
            access = CASE WHEN ? IS NOT NULL THEN excluded.access ELSE users.access END
        """, (email.strip().lower(), name.strip(), password, role, account_id, access_json, now_str, access_json if isinstance(access, dict) else None))
        conn.commit()
    finally:
        conn.close()
    return get_user(email)

def delete_user(email: str):
    conn = get_connection()
    try:
        conn.execute("DELETE FROM users WHERE email = ? COLLATE NOCASE AND role != 'staff'", (email.strip().lower(),))
        conn.commit()
    finally:
        conn.close()

def get_all_users():
    conn = get_connection()
    rows = conn.execute("SELECT email, name, password, role, account_id, access, created_at FROM users").fetchall()
    conn.close()
    return [_parse_user(r) for r in rows]

# --- Accounts ---
def get_all_accounts():
    conn = get_connection()
    rows = conn.execute("SELECT * FROM accounts").fetchall()
    conn.close()
    result = []
    for r in rows:
        acct = dict(r)
        extra = json.loads(acct.pop("data", "{}"))
        acct.update(extra)
        acct["created"] = acct.get("created") or acct.get("created_at") or datetime.now().strftime("%Y-%m-%d")
        result.append(acct)
    return result

def get_account(account_id: str):
    conn = get_connection()
    row = conn.execute("SELECT * FROM accounts WHERE id = ?", (account_id,)).fetchone()
    conn.close()
    if not row:
        return None
    acct = dict(row)
    extra = json.loads(acct.pop("data", "{}"))
    acct.update(extra)
    acct["created"] = acct.get("created") or acct.get("created_at") or datetime.now().strftime("%Y-%m-%d")
    return acct

def upsert_account(acct: dict):
    conn = get_connection()
    acct_id = acct.get("id")
    name = acct.get("name", "")
    solution = acct.get("solution", "data-foundation")
    region = acct.get("region", "eastus2")
    env = acct.get("env", "dev1")
    tenancy = acct.get("tenancy", "single")
    management = acct.get("management", "fully")
    status = acct.get("status", "provisioning")
    created = acct.get("created", datetime.now().strftime("%Y-%m-%d"))

    # Extract dynamic properties into data JSON
    extra_data = {
        "domains": acct.get("domains", []),
        "sandboxes": acct.get("sandboxes", []),
        "resources": acct.get("resources", {"spendLimitUsd": 5000, "storageGb": 500}),
        "usage": acct.get("usage", {"spendUsd": 0, "computeHours": 0}),
        "datasets": acct.get("datasets", [])
    }

    conn.execute("""
    INSERT INTO accounts (id, name, solution, region, env, tenancy, management, status, data, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        solution = excluded.solution,
        region = excluded.region,
        env = excluded.env,
        tenancy = excluded.tenancy,
        management = excluded.management,
        status = excluded.status,
        data = excluded.data
    """, (acct_id, name, solution, region, env, tenancy, management, status, json.dumps(extra_data), created))
    conn.commit()
    conn.close()

# --- Orders ---
def get_all_orders():
    conn = get_connection()
    rows = conn.execute("SELECT * FROM orders ORDER BY created_at DESC").fetchall()
    conn.close()
    result = []
    for r in rows:
        o = dict(r)
        extra = json.loads(o.pop("data", "{}"))
        o.update(extra)
        # Rename created_at to created for frontend compat
        o["created"] = o.pop("created_at")
        o["accountId"] = o.pop("account_id")
        o["requestedBy"] = o.pop("requested_by")
        result.append(o)
    return result

def upsert_order(order: dict):
    conn = get_connection()
    o_id = order.get("id")
    acct_id = order.get("accountId") or order.get("account_id")
    kind = order.get("kind", "provision")
    source = order.get("source", "sales")
    requested_by = order.get("requestedBy") or order.get("requested_by", "system")
    status = order.get("status", "pending")
    created = order.get("created") or order.get("created_at") or datetime.now().strftime("%Y-%m-%d %H:%M")

    extra_data = {
        "validation": order.get("validation", {"ok": True, "errors": [], "warnings": []}),
        "changes": order.get("changes", []),
        "jobs": order.get("jobs", []),
        "salesOrder": order.get("salesOrder", None),
        "logs": order.get("logs", [])
    }

    conn.execute("""
    INSERT INTO orders (id, account_id, kind, source, requested_by, status, data, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        account_id = excluded.account_id,
        kind = excluded.kind,
        source = excluded.source,
        requested_by = excluded.requested_by,
        status = excluded.status,
        data = excluded.data
    """, (o_id, acct_id, kind, source, requested_by, status, json.dumps(extra_data), created))
    conn.commit()
    conn.close()

# --- Work Orders ---
def get_all_work_orders():
    conn = get_connection()
    rows = conn.execute("SELECT * FROM work_orders ORDER BY id DESC").fetchall()
    conn.close()
    result = []
    for r in rows:
        w = dict(r)
        w["accountId"] = w.pop("account_id")
        w["by"] = w.pop("by_user")
        raw_m = w.get("metrics")
        if isinstance(raw_m, str):
            try:
                w["metrics"] = json.loads(raw_m)
            except Exception:
                w["metrics"] = []
        elif not isinstance(raw_m, list):
            w["metrics"] = []
        w["promoted"] = bool(w.get("promoted", 0))
        result.append(w)
    return result

def add_work_order(wo: dict):
    conn = get_connection()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    metrics_json = json.dumps(wo.get("metrics") or [])
    promoted_int = 1 if wo.get("promoted") else 0
    conn.execute("""
    INSERT INTO work_orders (id, account_id, by_user, verb, text, status, result, metrics, promoted, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        status = excluded.status,
        result = excluded.result,
        metrics = CASE WHEN excluded.metrics != '[]' THEN excluded.metrics ELSE work_orders.metrics END,
        promoted = excluded.promoted
    """, (
        wo.get("id"),
        wo.get("accountId") or wo.get("account_id"),
        wo.get("by") or wo.get("by_user", "user"),
        wo.get("verb", "EXPLORE"),
        wo.get("text", ""),
        wo.get("status", "queued"),
        wo.get("result", ""),
        metrics_json,
        promoted_int,
        now_str
    ))
    conn.commit()
    conn.close()

# --- Audit Logs ---
def get_all_audit_logs():
    conn = get_connection()
    rows = conn.execute("SELECT timestamp as t, actor, action, ref FROM audit_logs ORDER BY id DESC").fetchall()
    conn.close()
    return [dict(r) for r in rows]

def add_audit_log(actor: str, action: str, ref: str = ""):
    conn = get_connection()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    conn.execute("""
    INSERT INTO audit_logs (timestamp, actor, action, ref)
    VALUES (?, ?, ?, ?)
    """, (now_str, actor, action, ref))
    conn.commit()
    conn.close()

# --- Full State Snapshot ---
def get_full_state():
    return {
        "users": get_all_users(),
        "accounts": get_all_accounts(),
        "orders": get_all_orders(),
        "works": get_all_work_orders(),
        "audit": get_all_audit_logs()
    }
