# Engineering status and client acceptance

Code preparation and production acceptance are separate. The items below are
not all coding tasks and cannot be marked verified by a local schema check.

## Implemented in this package

| Control area | Code status | Remaining verification |
| --- | --- | --- |
| Deployment separation | Azure bootstrap and Databricks configuration in separate roots/state keys | First deployment and upgrade against real services |
| Credential handling | Managed-identity providers; no generated client secrets/PATs/SQL passwords; Key Vault URI references | Client identity grants, credential refresh and secret access denied to unauthorized identities |
| Network isolation | Private endpoints, per-subnet NSGs, firewall/default egress route, narrow control-plane rules | Regional Databricks dependencies, negative egress/lateral tests, endpoint approvals |
| DNS | Private DNS Resolver inbound endpoint and linked zones | Corporate/VPN forwarding, routes, central-zone ownership and browser-auth topology |
| Databricks data boundary | HIPAA profile, customer-account notebook results, UC isolation/bindings and compute ACLs | Group membership, supported entitlement/runtime/region, negative cross-workspace/user tests |
| Image selection | Required immutable application digest, identity-based private pull | Image exists, provenance/signature/SBOM and CVE triage |
| SQL migrations | MI authentication, validated TLS, parameterized metadata, transaction/rollback/version marker | Driver and DB integration, migration-role scope, existing-schema handling |
| Plan controls | Explicit saved-plan approval hash, selected fail-closed checks; no auto-unlock/delete/retry | Independent approval in the client's protected release process |
| Recovery safeguards | Soft deletion, purge protection, SQL PITR, Terraform guards and Azure RG deletion lock | Actual restore drills, RPO/RTO, long-term retention/HA policy |
| Logging | Service and data-plane diagnostics and firewall telemetry to Log Analytics | Actual ingestion/categories, central tamper-resistant archive, alerts and response tests |

## Still requiring engineering/integration beyond this package

- **Application source:** the archive does not contain the source/build of
  `adplatformapi`. Authentication inside the app, record-level authorization,
  tenant isolation, PHI handling, audit events and API tests remain unreviewed.
- **Existing Backstage app:** its create/delete authorization and ownership checks,
  catalog routing, sign-out/session handling and Azure DevOps integration need a
  separate production application review. Existing POC files are intentionally unchanged.
- **Runner supply chain:** the old mutable runner image and runtime installers are
  not reused. The new deployment helper expects an approved private managed-identity
  runner. Its base image, ODBC/Python dependencies, SBOM and vulnerability scanning
  still need a client-approved build/release integration.
- **Central operations:** central immutable/tamper-resistant audit archive, SIEM
  alerts, backup orchestration, HA/RPO/RTO choices and client VPN/hub integration are
  not provisioned by these workload stacks. Those must be integrated with the
  client's platform, not assumed to exist because logging is enabled.
- **Live acceptance:** no real Azure plan/apply, container boot, connectivity test,
  restore test, penetration test or cloud posture assessment has been performed.

These are explicit scope/evidence gaps, not claims that the code is already fully
compliant. The paid-subscription limitation does not prevent the implemented code
changes, but it does prevent closing the live acceptance items today.

## Required acceptance tests before PHI

1. Successful infrastructure and Databricks deployment using separate protected states.
2. Public access denied; VPN/runner DNS resolves expected private addresses.
3. Allowed service paths work; unapproved egress and lateral access fail.
4. App image digest matches approval; application starts and login/logout/expiry work.
5. Unauthorized users and cross-client users cannot read/create/delete environments or data.
6. Catalog links reach the correct resource group without granting extra Azure privileges.
7. UC bindings/permissions prevent cross-workspace and cross-group data access.
8. SQL login uses Entra and verified TLS; migration repeats safely and rolls back on failure.
9. Diagnostics arrive at the approved sink; a test security alert reaches the responder.
10. Restore a backup, measure RPO/RTO, and verify delete-lock and break-glass procedures.
11. Verify backend recovery/access controls, scan source/images/dependencies and triage findings.

## Organization-owned requirements

Legal/security must confirm BAA/service coverage, risk assessment, workforce access
and training, Conditional Access/PIM, incident/breach procedures, approved retention,
and applicable HITRUST assessment scope/evidence. A licensed assessment/assessor is
needed for an exact CSF control mapping and certification. No invented control IDs
or compliance percentages are supplied.

## Archive provenance and review scope

All 33 Terraform/script/YAML/SQL/Dockerfile source files in the supplied archive
were inventoried in the original pass. The extracted original remains under the
ignored `compliance-review-ad-env/` folder. The original guide and images are now
included in this package at the user's request; review screenshots for account
details before external distribution. Git history has not been copied.

The legacy runner's automatic unlocking, orphan deletion, broad grants, public
firewall exceptions and implicit applies were replaced by an explicit plan/apply
helper. Legacy encryption scripts with embedded credentials and silent success
were not reused. Initial schema statements were refactored into the migration helper.
The old ADE catalog runner reference is not deployed; this package uses the documented
two-phase operator workflow plus an opt-in validation-only pipeline.

Validation evidence: both Terraform configurations are formatted and schema-validated
against locked providers, PowerShell is syntax-checked, and Python synthetic regression
tests are executed locally. See the task handoff for the exact final test count.
