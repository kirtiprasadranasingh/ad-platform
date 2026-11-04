# Autonomous Data (AD) Platform

> **Enterprise-grade, self-service Autonomous Data Platform with automated Azure & Databricks cloud provisioning, natural-language infrastructure orchestration, and HIPAA/HITRUST compliant architecture.**

---

## Architecture Overview

```text
                                 ┌──────────────────────────────────────────────────┐
                                 │              Client Web Portal                   │
                                 │   - Self-service Registration                    │
                                 │   - Dedicated vs Shared Tenancy Selection        │
                                 │   - Configgy Infrastructure Assistant            │
                                 │   - ADy Autonomous Data Work Orders              │
                                 └────────────────────────┬─────────────────────────┘
                                                          │ HTTP / REST
                                                          ▼
                                 ┌──────────────────────────────────────────────────┐
                                 │             FastAPI Backend Engine               │
                                 │   - Multi-tenant Order Management                │
                                 │   - Dynamic .tfvars & backend.hcl Generator      │
                                 │   - 5-Phase Provisioning Orchestrator            │
                                 │   - Natural Language Command Parser              │
                                 └────────────────────────┬─────────────────────────┘
                                                          │ Orchestrates
                                                          ▼
                                 ┌──────────────────────────────────────────────────┐
                                 │           Hardened Terraform Engine              │
                                 │   - Fail-closed Gatekeeper (check_plan.py)       │
                                 │   - Zero Public Endpoints / Private Endpoints    │
                                 │   - Azure VNet Microsegmentation (7 Subnets)     │
                                 │   - Key Vault, Azure SQL, Private DNS, ACR       │
                                 │   - Databricks Unity Catalog & Metastore         │
                                 └──────────────────────────────────────────────────┘
```

---

## Repository Structure

```text
.
├── index.html                   # Master Frontend Single Page Application
├── flows.html                   # Architectural user flows and design system
├── backend/                     # Decoupled FastAPI backend service
│   ├── server.py                # REST API endpoints & static asset serving
│   ├── terraform_runner.py      # Dynamic Terraform config generator & stepper
│   ├── test_backend.py          # Automated verification test suite (6/6 checks)
│   └── runs/                    # Per-client isolated run outputs & state configs
├── terraform/                   # Production-hardened Azure Terraform codebase
│   ├── main.tf                  # Root module invoking adenv
│   ├── modules/adenv/           # Hardened infrastructure modules (38 files)
│   └── modules/shared/          # Shared private endpoints & diagnostic settings
├── databricks/                  # Phase 2 Databricks & Unity Catalog automation
│   ├── main.tf                  # Metastore, storage credentials & external locations
│   └── tests/                   # Terraform security tests
├── migrations/                  # Database migration scripts
│   └── create_schema.py         # Autonomous schema initialization
├── img/                         # Architecture & cloud setup documentation assets
├── check_plan.py                # Pre-apply security gatekeeper (fail-closed)
├── Dockerfile                   # Production container definition
├── docker-compose.yml           # Multi-platform deployment configuration
├── TERRAFORM-GUIDE.md           # In-depth 1,800+ line guide for Azure ADE & manual setup
└── README.md                    # This document
```

---

## Tenancy Models

The platform supports two distinct isolation architectures:

| Feature | Dedicated Tenancy (`single`) | Shared Tenancy (`multi`) |
| :--- | :--- | :--- |
| **Target Customers** | Enterprise / Regulated (HIPAA/HITRUST) | Cost-conscious / SMB / Trials |
| **Network Isolation** | Dedicated Resource Group (`rg-{client}-{env}`) and isolated VNet (`10.60.0.0/16`) | Shared Platform Resource Group (`rg-shared-adplatform`) & shared VNet (`10.80.0.0/16`) |
| **Compute & Storage** | Dedicated Azure SQL DB, Key Vault, and Storage Account | Shared Azure SQL Elastic Pool, Shared Storage Account with isolated container |
| **Databricks** | Dedicated Unity Catalog catalog & metastore assignment | Shared catalog with schema-level RBAC isolation |

---

## Security & Compliance Architecture

The bundled Terraform templates have been hardened to satisfy **HIPAA**, **HITRUST**, and enterprise security standards:

- **Zero Public Endpoints**: Every cloud resource (Key Vault, Storage Accounts, Azure SQL, ACR, Databricks) is accessed strictly via **Azure Private Endpoints**.
- **Micro-segmented Network**: VNet partitioned across 7 dedicated subnets (`public`, `private`, `egress`, `appservice`, `pe`, `sql`, `dbx-priv`) with strict NSG security rules.
- **Fail-Closed Security Gatekeeper**: `check_plan.py` analyzes `terraform plan -json` prior to execution. If any public IP or open ingress rule is detected, deployment aborts immediately.
- **TLS 1.2+ & Strong Ciphers**: Enforced across all endpoints and data-at-rest encryption.

---

## Quickstart

### 1. Run Locally

```bash
# Install Python dependencies
pip install fastapi uvicorn pydantic

# Run verification test suite
python backend/test_backend.py

# Launch backend server (serves frontend at http://localhost:8000)
python backend/server.py
```

### 2. Run with Docker Compose

```bash
docker compose up --build
```
Access the application at `http://localhost:8000`.

---

## Deployment to VPS (Coolify / Docker Compose)

1. **Create Repository**: Push this repository to your private GitHub organization (`https://github.com/<org>/ad-platform`).
2. **Coolify Service Configuration**:
   - In Coolify, add a **New Resource** -> **Docker Compose** or **GitHub Repository**.
   - Point to your repository and branch `main`.
   - Set exposed port: `8000`.
3. **Environment Variables**:
   ```ini
   TERRAFORM_DRY_RUN=true    # Keep true for simulated demo mode, set to false with Azure SP credentials
   PORT=8000
   ```

---

## Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `TERRAFORM_DRY_RUN` | `true` | When `true`, simulates cloud stepper with zero cloud cost. When `false`, runs real `terraform apply`. |
| `TF_ROOT` | Platform Root | Directory where `terraform/` and `databricks/` modules reside. |
| `PORT` | `8000` | HTTP port for FastAPI and the unified frontend. |

---

## Detailed Infrastructure Guide

For step-by-step Azure Service Principal creation, Azure Deployment Environments (ADE) configuration, Unity Catalog metastore setup, and manual Terraform deployment commands, see [TERRAFORM-GUIDE.md](TERRAFORM-GUIDE.md).
