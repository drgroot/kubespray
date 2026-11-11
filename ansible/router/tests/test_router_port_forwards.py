"""Offline tests for reconciliation against the installed AsusRouter package."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import AsyncMock

MODULE = Path(__file__).resolve().parents[1] / "library/asusrouter_port_forwards.py"
spec = importlib.util.spec_from_file_location("router_module", MODULE)
router_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(router_module)

FORWARD = dict(name="HTTPS", protocol="tcp", externalPort=443,
               internalIP="192.168.1.10", internalPort=443)


class ValidationTests(unittest.TestCase):
    def test_yaml_mapping_and_asus_nvram_format(self):
        self.assertEqual(router_module.compile_rules([FORWARD]),
                         "<HTTPS>443>192.168.1.10>443>TCP>>")

    def test_empty_table_clears_rules(self):
        self.assertEqual(router_module.compile_rules([]), "")

    def test_invalid_input(self):
        for override in ({"internalIP": "example.com"}, {"externalPort": 0},
                         {"internalPort": 65536}, {"name": "bad>name"}, {"name": ""}):
            with self.subTest(override=override), self.assertRaises(ValueError):
                router_module.compile_rules([dict(FORWARD, **override)])

    def test_overlapping_both_protocol_is_rejected(self):
        with self.assertRaises(ValueError):
            router_module.compile_rules([FORWARD, dict(FORWARD, name="Both", protocol="both")])

    def test_same_port_different_protocols(self):
        self.assertIn(">UDP>", router_module.compile_rules([FORWARD, dict(FORWARD, protocol="udp")]))


class ReconcileTests(unittest.IsolatedAsyncioTestCase):
    def router(self, rules="", state="1"):
        router = AsyncMock()
        router.async_connect.return_value = True
        router.async_api_hook.return_value = {"vts_rulelist": rules, "vts_enable_x": state}
        router.async_run_service.return_value = True
        return router

    async def test_no_change_with_html_encoding(self):
        desired = router_module.compile_rules([FORWARD])
        router = self.router(desired.replace("<", "&#60;").replace(">", "&#62;"))
        self.assertFalse(await router_module.reconcile(router, desired, True))
        router.async_run_service.assert_not_awaited()
        router.async_disconnect.assert_awaited_once()

    async def test_update_and_verify_correct_keys(self):
        desired = router_module.compile_rules([FORWARD])
        router = self.router()
        router.async_api_hook.side_effect = [
            {"vts_rulelist": "", "vts_enable_x": "0"},
            {"vts_rulelist": desired, "vts_enable_x": "1"},
        ]
        self.assertTrue(await router_module.reconcile(router, desired, True))
        router.async_run_service.assert_awaited_once_with(
            service="restart_firewall", arguments={"vts_rulelist": desired, "vts_enable_x": 1}, apply=True)
        router.async_api_hook.assert_awaited_with("nvram_get(vts_rulelist);nvram_get(vts_enable_x);")

    async def test_clear_table_and_disable(self):
        router = self.router()
        router.async_api_hook.side_effect = [
            {"vts_rulelist": router_module.compile_rules([FORWARD]), "vts_enable_x": "1"},
            {"vts_rulelist": "", "vts_enable_x": "0"},
        ]
        self.assertTrue(await router_module.reconcile(router, "", False))
        self.assertEqual(router.async_run_service.call_args.kwargs["arguments"],
                         {"vts_rulelist": "", "vts_enable_x": 0})

    async def test_check_mode_never_writes(self):
        router = self.router()
        self.assertTrue(await router_module.reconcile(router, router_module.compile_rules([FORWARD]), True, True))
        router.async_run_service.assert_not_awaited()

    async def test_unreadable_table_never_writes(self):
        router = self.router()
        router.async_api_hook.return_value = {}
        with self.assertRaises(ValueError):
            await router_module.reconcile(router, "", True)
        router.async_run_service.assert_not_awaited()
        router.async_disconnect.assert_awaited_once()

    async def test_failed_apply_is_reported(self):
        router = self.router()
        router.async_run_service.return_value = False
        with self.assertRaises(ValueError):
            await router_module.reconcile(router, router_module.compile_rules([FORWARD]), True)
        router.async_disconnect.assert_awaited_once()

    async def test_login_failure_disconnects(self):
        router = self.router()
        router.async_connect.return_value = False
        with self.assertRaises(ValueError):
            await router_module.reconcile(router, "", True)
        router.async_api_hook.assert_not_awaited()
        router.async_disconnect.assert_awaited_once()


if __name__ == "__main__":
    unittest.main()
