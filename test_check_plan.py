import copy
import unittest
from check_plan import RULES, MANDATORY, check


def fixture():
    items = []
    for kind, fields in RULES.items():
        values = dict(fields)
        if kind == "azurerm_linux_web_app":
            values["site_config"] = [{"application_stack": [{"docker_image_name": "api@sha256:" + "a" * 64}]}]
            values["ftp_publish_basic_authentication_enabled"] = False
            values["webdeploy_publish_basic_authentication_enabled"] = False
        if kind == "azurerm_firewall_policy":
            values["intrusion_detection"] = [{"mode": "Deny"}]
        if kind == "azurerm_mssql_server":
            values["azuread_administrator"] = [{"azuread_authentication_only": True}]
        if kind == "azurerm_databricks_workspace":
            values["enhanced_security_compliance"] = [{
                "automatic_cluster_update_enabled": True,
                "enhanced_security_monitoring_enabled": True,
                "compliance_security_profile_enabled": True,
                "compliance_security_profile_standards": ["HIPAA"],
            }]
        items.append({"mode": "managed", "type": kind, "address": kind + ".test",
                      "change": {"actions": ["create"], "after": values, "after_unknown": {}}})
    for kind in sorted(MANDATORY["infrastructure"] - set(RULES)):
        items.append({"mode": "managed", "type": kind, "address": kind + ".test",
                      "change": {"actions": ["create"], "after": {}, "after_unknown": {}}})
    return {"resource_changes": items}


class Guardrails(unittest.TestCase):
    def test_baseline(self):
        self.assertEqual(check(fixture()), [])

    def test_every_required_control_is_fail_closed(self):
        for index, item in enumerate(fixture()["resource_changes"]):
            for field in RULES.get(item["type"], {}):
                for mutation in ("absent", "unknown", "wrong"):
                    with self.subTest(kind=item["type"], field=field, mutation=mutation):
                        plan = copy.deepcopy(fixture())
                        change = plan["resource_changes"][index]["change"]
                        if mutation == "absent":
                            del change["after"][field]
                        elif mutation == "unknown":
                            change["after_unknown"][field] = True
                        else:
                            change["after"][field] = "insecure"
                        self.assertTrue(check(plan))

    def test_empty_partial_and_malformed(self):
        for plan in ({}, {"resource_changes": []}, {"resource_changes": fixture()["resource_changes"][:-1]}):
            self.assertTrue(check(plan))

    def test_replacement(self):
        plan = fixture()
        plan["resource_changes"][0]["change"]["actions"] = ["delete", "create"]
        self.assertTrue(check(plan))

    def test_profile_removed(self):
        plan = fixture()
        for item in plan["resource_changes"]:
            if item["type"] == "azurerm_databricks_workspace":
                item["change"]["after"]["enhanced_security_compliance"] = []
        self.assertTrue(check(plan))

    def test_mutable_image_is_rejected(self):
        plan = fixture()
        for item in plan["resource_changes"]:
            if item["type"] == "azurerm_linux_web_app":
                item["change"]["after"]["site_config"][0]["application_stack"][0]["docker_image_name"] = "api:latest"
        self.assertTrue(check(plan))

    def test_missing_firewall_is_rejected(self):
        plan = fixture()
        plan["resource_changes"] = [i for i in plan["resource_changes"] if i["type"] != "azurerm_firewall"]
        self.assertTrue(check(plan))

    def test_databricks_phase(self):
        items = []
        for kind in sorted(MANDATORY["databricks"]):
            values = {"owner": "restricted-team", "force_destroy": False, "isolation_mode": "ISOLATED",
                      "data_security_mode": "USER_ISOLATION",
                      "custom_config": {"storeInteractiveNotebookResultsInCustomerAccount": "true"}}
            items.append({"mode": "managed", "type": kind, "address": kind + ".test",
                          "change": {"actions": ["create"], "after": values}})
        plan = {"resource_changes": items}
        self.assertEqual(check(plan, "databricks"), [])
        self.assertTrue(check(plan, "infrastructure"))
        items[0]["change"]["after"]["isolation_mode"] = "OPEN"
        self.assertTrue(check(plan, "databricks"))

    def test_pat(self):
        plan = fixture()
        plan["resource_changes"].append({"mode": "managed", "type": "databricks_token", "address": "token.test", "change": {"after": {}}})
        self.assertTrue(check(plan))

    def test_sql_authentication_cannot_fall_back_to_password(self):
        plan = fixture()
        for item in plan["resource_changes"]:
            if item["type"] == "azurerm_mssql_server":
                item["change"]["after"]["azuread_administrator"] = [{"azuread_authentication_only": False}]
        self.assertTrue(check(plan))


if __name__ == "__main__":
    unittest.main()
