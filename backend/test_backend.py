"""
Self-Contained Verification Check for AD Platform Backend
Runs without external test frameworks.
Execute with: python backend/test_backend.py
"""

import sys
import os
from pathlib import Path

# Add backend directory to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from terraform_runner import generate_tfvars, run_provisioning_workflow
from server import app, DB
from fastapi.testclient import TestClient

client = TestClient(app)


def test_tfvars_generation():
    print("[1/5] Testing Dedicated vs Shared tfvars generation...")
    
    # Test 1: Dedicated
    dedicated_order = {
        "org": "CompanyA",
        "env": "prod",
        "region": "eastus2",
        "tenancy": "single",
        "storage": 250,
        "sandbox": "sbx-primary"
    }
    ded_paths = generate_tfvars(dedicated_order)
    assert ded_paths["is_shared"] is False, "Dedicated should not be shared"
    assert ded_paths["prefix"] == "companya-prod"
    tfvars_text = ded_paths["tfvars"].read_text(encoding="utf-8")
    assert 'resource_group_name          = "rg-companya-prod"' in tfvars_text
    assert '10.60.0.0/16' in tfvars_text

    # Test 2: Shared
    shared_order = {
        "org": "CompanyB",
        "env": "dev1",
        "region": "eastus2",
        "tenancy": "multi",
        "storage": 50,
        "sandbox": "sbx-team"
    }
    sh_paths = generate_tfvars(shared_order)
    assert sh_paths["is_shared"] is True, "Shared should be flagged as shared"
    sh_tfvars = sh_paths["tfvars"].read_text(encoding="utf-8")
    assert 'resource_group_name          = "rg-shared-storage-poc"' in sh_tfvars
    assert '10.80.0.0/16' in sh_tfvars
    print("      PASS: Dedicated and Shared configurations correctly generated.")


def test_provisioning_workflow_steps():
    print("[2/5] Testing 5-step provisioning workflow...")
    steps_hit = []

    def callback(step, status, log):
        if status == "done":
            steps_hit.append(step)

    order = {
        "org": "TestCorp",
        "env": "dev1",
        "tenancy": "single",
        "sandbox": "sbx-test",
        "storage": 100
    }
    result = run_provisioning_workflow(order, progress_callback=callback)
    expected_steps = [
        "Validate sales order",
        "Environment setup (ADAzEnvConfig)",
        "Service configuration (ADSvcConfig)",
        "Jumpstart AD",
        "Verify"
    ]
    assert steps_hit == expected_steps, f"Expected {expected_steps}, got {steps_hit}"
    assert result["status"] == "ready"
    print("      PASS: All 5 provisioning phases completed in sequence.")


def test_api_health_and_accounts():
    print("[3/6] Testing Health Check and Multi-Tenant Account endpoints...")
    res = client.get("/api/health")
    assert res.status_code == 200
    assert res.json()["terraform_backend_ready"] is True

    res = client.get("/api/accounts")
    assert res.status_code == 200
    accounts = res.json()
    assert len(accounts) >= 1
    assert accounts[0]["id"] == "alida-internal"
    print("      PASS: API health and account endpoints verified.")


def test_api_auto_provision_on_registration():
    print("[4/6] Testing Automatic Terraform Trigger on Registration (/api/register)...")
    reg_payload = {
        "name": "Jane Doe",
        "org": "Healthcare Systems",
        "email": "jane@healthsys.org",
        "password": "securepassword123",
        "region": "eastus2",
        "tenancy": "single",
        "storage": 500,
        "sandbox": "sbx-clinical",
        "quota": 100,
        "spend": 8000.0
    }
    res = client.post("/api/register", json=reg_payload)
    assert res.status_code == 200
    data = res.json()
    assert "orderId" in data
    assert "accountId" in data
    assert data["status"] == "running"
    print(f"      PASS: Registration automatically triggered Terraform order: {data['orderId']}")


def test_api_provision_dispatch():
    print("[5/6] Testing POST /api/orders/provision...")
    payload = {
        "org": "Fintech Solutions",
        "adminEmail": "lead@fintech.com",
        "adminName": "Lead Architect",
        "solution": "data-foundation",
        "region": "eastus2",
        "tenancy": "single",
        "management": "fully",
        "storage": 500,
        "sandbox": "sbx-data",
        "quota": 100,
        "spend": 10000.0,
        "users": [{"email": "dev1@fintech.com", "admin": False}]
    }
    res = client.post("/api/orders/provision", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert "orderId" in data
    order_id = data["orderId"]

    # Poll status
    status_res = client.get(f"/api/orders/{order_id}")
    assert status_res.status_code == 200
    order_data = status_res.json()
    assert order_data["id"] == order_id
    assert len(order_data["jobs"]) == 5
    print("      PASS: Provisioning order successfully created and queried.")


def test_assistant_command():
    print("[5/5] Testing Configgy Assistant commands...")
    # Add sandbox command
    cmd1 = {"accountId": "alida-internal", "text": "add sandbox data-analytics 80 gb"}
    res1 = client.post("/api/assistant/command", json=cmd1)
    assert res1.status_code == 200
    d1 = res1.json()
    assert any(c["name"] == "data-analytics" for c in d1["changes"])

    # Update spending limit command
    cmd2 = {"accountId": "alida-internal", "text": "increase spending limit to $7500"}
    res2 = client.post("/api/assistant/command", json=cmd2)
    assert res2.status_code == 200
    d2 = res2.json()
    assert any(c["target"] == "resources" and c["spendLimitUsd"] == 7500 for c in d2["changes"])
    print("      PASS: Natural language commands parsed and mutated account state.")


def test_ady_work_orders():
    print("[6/6] Testing ADy Data Assistant Work Orders...")
    # 1. Profile dataset
    wo1 = {"accountId": "alida-internal", "verb": "DATA", "text": "profile store_master"}
    r1 = client.post("/api/assistant/workorder", json=wo1)
    assert r1.status_code == 200
    d1 = r1.json()
    assert "store_master" in d1["result"]
    assert d1["status"] == "done"

    # 2. Produce data foundation
    wo2 = {"accountId": "alida-internal", "verb": "PRODUCE", "text": "produce a data foundation from the retail datasets"}
    r2 = client.post("/api/assistant/workorder", json=wo2)
    assert r2.status_code == 200
    d2 = r2.json()
    assert "retail_foundation" in d2["result"]

    # 3. Query work orders
    r_list = client.get("/api/workorders?accountId=alida-internal")
    assert r_list.status_code == 200
    assert len(r_list.json()) >= 2
    print("      PASS: ADy data operations executed and work orders logged.")


if __name__ == "__main__":
    print("Running AD Platform Backend Verification Suite...")
    try:
        test_tfvars_generation()
        test_provisioning_workflow_steps()
        test_api_health_and_accounts()
        test_api_auto_provision_on_registration()
        test_api_provision_dispatch()
        test_assistant_command()
        test_ady_work_orders()
        print("\nALL CHECKS PASSED SUCCESSFULLY (7/7)!")
    except AssertionError as e:
        print(f"\nCHECK FAILED: {e}")
        sys.exit(1)
