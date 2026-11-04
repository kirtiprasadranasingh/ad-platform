"""Small fail-closed engineering guardrail; not a HIPAA/HITRUST assessment.

Input: terraform show -json <saved-plan>. Treat that JSON as a secret artifact.
Only resource addresses and control names are printed, never attribute values.
"""
import json
import sys
import re


RULES = {
    "azurerm_storage_account": {
        "public_network_access_enabled": False,
        "shared_access_key_enabled": False,
        "allow_nested_items_to_be_public": False,
        "https_traffic_only_enabled": True,
        "min_tls_version": "TLS1_2",
        "infrastructure_encryption_enabled": True,
    },
    "azurerm_storage_container": {"container_access_type": "private"},
    "azurerm_key_vault": {
        "public_network_access_enabled": False,
        "rbac_authorization_enabled": True,
        "purge_protection_enabled": True,
        "soft_delete_retention_days": 90,
    },
    "azurerm_mssql_server": {
        "public_network_access_enabled": False,
        "minimum_tls_version": "1.2",
    },
    "azurerm_mssql_database": {"transparent_data_encryption_enabled": True},
    "azurerm_container_registry": {
        "admin_enabled": False,
        "public_network_access_enabled": False,
        "network_rule_bypass_option": "None",
    },
    "azurerm_linux_web_app": {
        "https_only": True,
        "public_network_access_enabled": False,
    },
    "azurerm_databricks_workspace": {
        "public_network_access_enabled": False,
        "infrastructure_encryption_enabled": True,
    },
    "azurerm_firewall_policy": {"sku": "Premium", "threat_intelligence_mode": "Deny"},
}

MANDATORY = {
    "infrastructure": set(RULES) | {"azurerm_firewall", "azurerm_route_table",
        "azurerm_subnet_route_table_association", "azurerm_network_security_rule",
        "azurerm_private_dns_resolver_inbound_endpoint", "azurerm_monitor_diagnostic_setting"},
    "databricks": {"databricks_cluster", "databricks_workspace_conf",
        "databricks_catalog", "databricks_schema", "databricks_storage_credential",
        "databricks_external_location", "databricks_workspace_binding", "databricks_permissions"},
}


def check(plan, phase="infrastructure"):
    if phase not in MANDATORY:
        return ["Unknown deployment phase"]
    if not isinstance(plan, dict) or not isinstance(plan.get("resource_changes"), list):
        return ["Invalid plan or missing resource_changes"]
    errors, seen = [], set()
    for item in plan["resource_changes"]:
        if item.get("mode") != "managed":
            continue
        kind, address = item.get("type"), item.get("address", "unknown-resource")
        seen.add(kind)
        change = item.get("change") or {}
        if "delete" in change.get("actions", []):
            errors.append(f"{address}: deletion/replacement requires separate recovery review")
        values = change.get("after") or {}
        unknown = change.get("after_unknown") or {}
        for field, expected in RULES.get(kind, {}).items():
            if unknown.get(field) or field not in values or type(values[field]) is not type(expected) or values[field] != expected:
                errors.append(f"{address}: {field} missing, unknown, or insecure")
        if kind == "azurerm_linux_web_app":
            site = (values.get("site_config") or [{}])[0]
            stack = (site.get("application_stack") or [{}])[0]
            if not re.fullmatch(r"[a-z0-9][a-z0-9/_.-]*@sha256:[a-f0-9]{64}", stack.get("docker_image_name", "")):
                errors.append(f"{address}: immutable application image required")
            if values.get("ftp_publish_basic_authentication_enabled") is not False or values.get("webdeploy_publish_basic_authentication_enabled") is not False:
                errors.append(f"{address}: publishing basic authentication forbidden")
        if kind == "azurerm_firewall_policy":
            if (values.get("intrusion_detection") or [{}])[0].get("mode") != "Deny":
                errors.append(f"{address}: deny-mode intrusion detection required")
        if kind == "azurerm_databricks_workspace":
            profile = values.get("enhanced_security_compliance") or []
            required = ("automatic_cluster_update_enabled", "enhanced_security_monitoring_enabled", "compliance_security_profile_enabled")
            if len(profile) != 1 or any(profile[0].get(k) is not True for k in required) or "HIPAA" not in profile[0].get("compliance_security_profile_standards", []):
                errors.append(f"{address}: missing Databricks HIPAA security profile")
        if kind == "azurerm_mssql_server":
            administrators = values.get("azuread_administrator") or []
            if len(administrators) != 1 or administrators[0].get("azuread_authentication_only") is not True:
                errors.append(f"{address}: Entra-only SQL authentication required")
        if kind == "azurerm_log_analytics_workspace":
            days = values.get("retention_in_days")
            if not isinstance(days, int) or days < 90:
                errors.append(f"{address}: baseline interactive retention below 90 days or unknown")
        if kind == "azurerm_role_assignment" and values.get("role_definition_name") in {"Owner", "Contributor", "Storage Blob Data Owner"}:
            errors.append(f"{address}: broad role forbidden in workload baseline")
        if kind in {"databricks_catalog", "databricks_schema", "databricks_external_location", "databricks_storage_credential"}:
            owner = values.get("owner")
            if not isinstance(owner, str) or not owner.strip() or owner.lower() in {"users", "account users"}:
                errors.append(f"{address}: restricted known owner required")
            if values.get("force_destroy") is not False:
                errors.append(f"{address}: force_destroy must be explicitly false")
            if kind != "databricks_schema" and values.get("isolation_mode") != "ISOLATED":
                errors.append(f"{address}: workspace isolation required")
        if kind == "databricks_workspace_conf":
            config = values.get("custom_config") or {}
            if config.get("storeInteractiveNotebookResultsInCustomerAccount") != "true":
                errors.append(f"{address}: customer-account notebook result storage required")
        if kind == "databricks_cluster":
            if values.get("data_security_mode") != "USER_ISOLATION":
                errors.append(f"{address}: isolated compute required")
        if kind == "databricks_token":
            errors.append(f"{address}: persistent PAT provisioning is forbidden")
    for kind in sorted(MANDATORY[phase] - seen):
        errors.append(f"Missing mandatory resource type: {kind}; partial plans are not accepted")
    return errors


if __name__ == "__main__":
    try:
        phase = sys.argv[2] if len(sys.argv) > 2 else "infrastructure"
        if sys.argv[1] == "-":
            failures = check(json.loads(sys.stdin.read().lstrip("\ufeff")), phase)
        else:
            with open(sys.argv[1], encoding="utf-8-sig") as stream:
                failures = check(json.load(stream), phase)
    except (IndexError, OSError, ValueError, TypeError, AttributeError):
        print("Cannot read plan JSON; refusing approval.", file=sys.stderr)
        sys.exit(2)
    for failure in failures:
        print(failure, file=sys.stderr)
    if failures:
        sys.exit(1)
    print("Engineering checks passed. Organizational approval and live validation still required.")
