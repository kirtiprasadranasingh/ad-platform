"""
AD Platform Backend API Service
Connects frontend UI (index.html) and Assistant (Configgy) to the Terraform execution runner.
"""

import os
import re
import uuid
import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional

from fastapi import FastAPI, BackgroundTasks, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from terraform_runner import run_provisioning_workflow, DRY_RUN

BASE_DIR = Path(__file__).resolve().parent.parent

app = FastAPI(
    title="AD Platform Provisioning & Orchestration API",
    description="Backend service connecting ADaaS onboarding and Configgy assistant to Terraform",
    version="1.0.0"
)

# Enable CORS for frontend flexibility
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------- IN-MEMORY STATE STORE -----------------
# Stores multi-tenant accounts and provisioning orders
DB = {
    "accounts": [
        {
            "id": "alida-internal",
            "name": "Alida Internal (first client)",
            "solution": "data-foundation",
            "region": "eastus2",
            "tenancy": "single",
            "management": "fully",
            "status": "ready",
            "domains": ["gendf", "readygo-retail"],
            "sandboxes": [{"name": "sbx-main", "mode": "dedicated", "quotaGb": 100}],
            "resources": {"spendLimitUsd": 5000, "storageGb": 500},
            "usage": {"spendUsd": 1840, "computeHours": 62},
            "created": "2026-11-20"
        }
    ],
    "orders": {},
    "logs": []
}


# ----------------- PYDANTIC SCHEMAS -----------------
class UserItem(BaseModel):
    email: str
    admin: bool = False


class ProvisionPayload(BaseModel):
    org: str = Field(..., example="Acme Corp")
    adminEmail: str = Field(..., example="admin@acme.com")
    adminName: Optional[str] = "Admin User"
    solution: str = Field("data-foundation", example="data-foundation")
    region: str = Field("eastus2", example="eastus2")
    tenancy: str = Field("single", example="single")  # single (dedicated) or multi (shared)
    management: str = Field("fully", example="fully")  # self or fully
    storage: int = Field(100, example=100)
    sandbox: str = Field("sbx-main", example="sbx-main")
    quota: int = Field(50, example=50)
    spend: float = Field(5000.0, example=5000.0)
    users: List[UserItem] = []


class AssistantCommand(BaseModel):
    accountId: str = Field("alida-internal", example="alida-internal")
    text: str = Field(..., example="add sandbox analytics 100 gb")


class RegisterPayload(BaseModel):
    name: str = Field(..., example="Alice Smith")
    org: str = Field(..., example="Acme Corp")
    email: str = Field(..., example="alice@acme.com")
    password: str = Field("welcome", example="welcome")
    region: str = Field("eastus2", example="eastus2")
    tenancy: str = Field("single", example="single")  # single or multi
    storage: int = Field(500, example=500)
    sandbox: str = Field("sbx-main", example="sbx-main")
    quota: int = Field(100, example=100)
    spend: float = Field(5000.0, example=5000.0)


# ----------------- BACKGROUND WORKER -----------------
def async_provision_task(order_id: str, payload_dict: Dict[str, Any]):
    order = DB["orders"][order_id]
    
    def on_progress(step_name: str, status: str, log_msg: str):
        for job in order["jobs"]:
            if job[0] == step_name:
                job[1] = status
                break
        order["logs"].append({
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "step": step_name,
            "status": status,
            "message": log_msg
        })

    try:
        result = run_provisioning_workflow(payload_dict, progress_callback=on_progress)
        order["status"] = "applied"
        order["result"] = result
        
        # Mark account ready
        for acct in DB["accounts"]:
            if acct["id"] == order["accountId"]:
                acct["status"] = "ready"
                break
    except Exception as e:
        order["status"] = "failed"
        order["error"] = str(e)


# ----------------- REST API ROUTES -----------------
@app.get("/api/health")
def health_check():
    return {
        "status": "healthy",
        "dry_run_mode": DRY_RUN,
        "terraform_backend_ready": True
    }


@app.get("/api/accounts")
def list_accounts():
    """List multi-tenant accounts (Company A, Company B)."""
    return DB["accounts"]


@app.get("/api/accounts/{account_id}")
def get_account(account_id: str):
    acct = next((a for a in DB["accounts"] if a["id"] == account_id), None)
    if not acct:
        raise HTTPException(status_code=404, detail="Account not found")
    return acct


@app.get("/api/accounts/{account_id}/tfvars")
def get_account_tfvars(account_id: str):
    """Returns the live generated infrastructure.tfvars file for this tenant."""
    clean_org = re.sub(r"[^a-z0-9]", "", account_id.replace("acct-", "").lower())[:8]
    tfvars_path = Path(__file__).resolve().parent / "runs" / clean_org / "dev1" / "infrastructure.tfvars"
    if tfvars_path.exists():
        return {"found": True, "filename": str(tfvars_path), "content": tfvars_path.read_text(encoding="utf-8")}
    # Also check if it's in a subdirectory
    runs_dir = Path(__file__).resolve().parent / "runs"
    for p in runs_dir.glob(f"*{clean_org}*/**/infrastructure.tfvars"):
        return {"found": True, "filename": str(p), "content": p.read_text(encoding="utf-8")}
    return {"found": False, "filename": "", "content": "# Configuration pending generation..."}


@app.post("/api/register")
def register_and_provision(payload: RegisterPayload, background_tasks: BackgroundTasks):
    """
    Automatic provisioning trigger on client registration.
    Registers client account, generates Terraform tfvars, and immediately executes provisioning.
    """
    provision_payload = ProvisionPayload(
        org=payload.org,
        adminEmail=payload.email,
        adminName=payload.name,
        solution="data-foundation",
        region=payload.region,
        tenancy=payload.tenancy,
        management="fully" if payload.tenancy == "single" else "self",
        storage=payload.storage,
        sandbox=payload.sandbox,
        quota=payload.quota,
        spend=payload.spend,
        users=[]
    )
    return create_provision_order(provision_payload, background_tasks)


@app.post("/api/orders/provision")
def create_provision_order(payload: ProvisionPayload, background_tasks: BackgroundTasks):
    """
    Triggers Terraform environment provisioning on form confirmation.
    Dedicated tenancy: creates new isolated RG, VNet, SA, Key Vault, and Databricks.
    Shared tenancy: allocates resources on shared platform.
    """
    clean_org = re.sub(r"[^a-z0-9]", "-", payload.org.lower()).strip("-")
    account_id = f"acct-{clean_org}"
    order_id = f"CO-{uuid.uuid4().hex[:6].upper()}"

    # Register new account in DB
    new_account = {
        "id": account_id,
        "name": payload.org,
        "solution": payload.solution,
        "region": payload.region,
        "tenancy": payload.tenancy,
        "management": payload.management,
        "status": "provisioning",
        "domains": [payload.solution],
        "sandboxes": [{"name": payload.sandbox, "mode": "dedicated", "quotaGb": payload.quota}],
        "resources": {"spendLimitUsd": payload.spend, "storageGb": payload.storage},
        "usage": {"spendUsd": 0, "computeHours": 0},
        "created": datetime.date.today().isoformat()
    }
    DB["accounts"].append(new_account)

    # Initial order record matching frontend stepper
    order_record = {
        "id": order_id,
        "accountId": account_id,
        "kind": "provision",
        "status": "running",
        "created": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "jobs": [
            ["Validate sales order", "pending"],
            ["Environment setup (ADAzEnvConfig)", "pending"],
            ["Service configuration (ADSvcConfig)", "pending"],
            ["Jumpstart AD", "pending"],
            ["Verify", "pending"]
        ],
        "changes": [
            {"op": "provision", "target": "environment", "value": f"{payload.region} • {payload.tenancy}-tenant • {payload.management} managed"},
            {"op": "add", "target": "sandbox", "name": payload.sandbox, "mode": "dedicated", "quotaGb": payload.quota},
            {"op": "set", "target": "resources", "spendLimitUsd": payload.spend, "storageGb": payload.storage}
        ],
        "logs": []
    }
    DB["orders"][order_id] = order_record

    # Dispatch asynchronous Terraform workflow
    background_tasks.add_task(async_provision_task, order_id, payload.model_dump())

    return {
        "orderId": order_id,
        "accountId": account_id,
        "status": "running",
        "message": f"Terraform provisioning dispatched for {payload.org} ({'Shared' if payload.tenancy == 'multi' else 'Dedicated'})"
    }


@app.get("/api/orders/{order_id}")
def get_order_status(order_id: str):
    """Poll live job progress and step status for the frontend stepper."""
    order = DB["orders"].get(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@app.post("/api/assistant/command")
def parse_assistant_command(cmd: AssistantCommand):
    """
    Handles natural language assistant commands (Configgy).
    E.g.: 'add sandbox analytics 60 gb', 'increase spending limit to 8000', 'remove sandbox test'
    """
    text = cmd.text.lower().strip()
    acct = next((a for a in DB["accounts"] if a["id"] == cmd.accountId), None)
    if not acct:
        raise HTTPException(status_code=404, detail="Account not found")

    changes = []
    response_text = ""

    # 1. Add sandbox regex
    m_sbx = re.search(r"add (?:a )?sandbox\s+([a-z0-9_-]+)(?:\s+(\d+)\s*gb)?", text)
    if m_sbx:
        sbx_name = m_sbx.group(1)
        quota = int(m_sbx.group(2) or 50)
        acct["sandboxes"].append({"name": sbx_name, "mode": "dedicated", "quotaGb": quota})
        changes.append({"op": "add", "target": "sandbox", "name": sbx_name, "quotaGb": quota})
        response_text = f"Added sandbox '{sbx_name}' with {quota} GB quota to account {acct['name']}."

    # 2. Spend limit regex
    m_spend = re.search(r"(?:increase|set|change) spending limit to\s*\$?(\d+)", text)
    if m_spend:
        new_spend = float(m_spend.group(1))
        acct["resources"]["spendLimitUsd"] = new_spend
        changes.append({"op": "set", "target": "resources", "spendLimitUsd": new_spend})
        response_text = f"Updated spending limit to ${new_spend:,.0f} for account {acct['name']}."

    # 3. Add domain
    m_dom = re.search(r"add domain\s+([a-z0-9_-]+)", text)
    if m_dom:
        dom = m_dom.group(1)
        if dom not in acct["domains"]:
            acct["domains"].append(dom)
            changes.append({"op": "add", "target": "domain", "id": dom})
            response_text = f"Added domain '{dom}' to account {acct['name']}."

    if not changes:
        response_text = f"I understood your request ('{cmd.text}'). No matching configuration mutation pattern found. Try: 'add sandbox dev 50 gb' or 'set spending limit to 6000'."

    return {
        "response": response_text,
        "changes": changes,
        "account": acct
    }


# Mount the root frontend directory so opening http://localhost:8000 serves index.html
if BASE_DIR.exists():
    app.mount("/", StaticFiles(directory=str(BASE_DIR), html=True), name="static")

if __name__ == "__main__":
    import uvicorn
    print(f"Starting AD Platform Backend on http://127.0.0.1:8000 (DRY_RUN={DRY_RUN})...")
    uvicorn.run("server:app", host="127.0.0.1", port=8000, reload=False)
