"""Offline DHCP reconciliation tests; no live router or backup required."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import AsyncMock, patch

MODULE = Path(__file__).resolve().parents[1] / "library/asusrouter_dhcp_reservations.py"
spec = importlib.util.spec_from_file_location("dhcp_module", MODULE)
dhcp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dhcp)
RESERVATION = {"name": "server", "mac": "24:5E:BE:81:85:01", "ip": "192.168.1.3"}
TABLE = "<24:5E:BE:81:85:01>192.168.1.3>>server"


def state(table="", enabled="1"):
    return {"dhcp_staticlist": table, "dhcp_static_x": enabled,
            "lan_ipaddr": "192.168.1.1", "lan_netmask": "255.255.255.0"}


class ValidationTests(unittest.TestCase):
    def compile(self, rows, current=""):
        return dhcp.compile_table(rows, current, "192.168.1.1", "255.255.255.0")

    def test_asus_serialization(self):
        self.assertEqual(self.compile([RESERVATION]), TABLE)

    def test_empty_name_and_clearing_table(self):
        self.assertEqual(self.compile([dict(RESERVATION, name="")]), TABLE.removesuffix("server"))
        self.assertEqual(self.compile([], TABLE), "")

    def test_preserves_existing_device_dns(self):
        old = TABLE.replace(">>server", ">192.168.1.50>server")
        self.assertEqual(self.compile([RESERVATION], old), old)
        self.assertEqual(self.compile([dict(RESERVATION, dns="")], old), TABLE)
        self.assertIn(">192.168.1.2>", self.compile([dict(RESERVATION, dns="192.168.1.2")], old))

    def test_invalid_reservations(self):
        for override in ({"ip": "192.168.2.3"}, {"ip": "192.168.1.1"},
                         {"ip": "192.168.1.0"}, {"ip": "192.168.1.255"},
                         {"ip": "example.com"}, {"mac": "bad"},
                         {"mac": "01:00:00:00:00:01"}, {"mac": "00:00:00:00:00:00"},
                         {"name": "bad>hostname"}, {"name": "x" * 33}, {"dns": "bad"}):
            with self.subTest(override=override), self.assertRaises(ValueError):
                self.compile([dict(RESERVATION, **override)])

    def test_duplicate_mac_ip_and_name(self):
        for override in ({"mac": "24:5e:be:81:85:01", "ip": "192.168.1.4", "name": "other"},
                         {"mac": "02:00:00:00:00:02", "name": "other"},
                         {"mac": "02:00:00:00:00:02", "ip": "192.168.1.4", "name": "SERVER"}):
            with self.subTest(override=override), self.assertRaises(ValueError):
                self.compile([RESERVATION, dict(RESERVATION, **override)])

    def test_legacy_empty_columns_and_entities(self):
        encoded = "&#6024:5e:be:81:85:01&#62192.168.1.3"
        self.assertEqual(dhcp.parse_table(encoded), [(RESERVATION['mac'], RESERVATION['ip'], '', '')])

    def test_unknown_format_is_rejected(self):
        with self.assertRaises(ValueError):
            dhcp.parse_table(TABLE + ">extra")


class ReconcileTests(unittest.IsolatedAsyncioTestCase):
    def router(self, current=None):
        router = AsyncMock()
        router.async_connect.return_value = True
        router.async_api_hook.return_value = state() if current is None else current
        router.async_run_service.return_value = True
        return router

    async def test_no_change_ignores_order_mac_case_and_entities(self):
        other = "<02:00:00:00:00:02>192.168.1.4>>other"
        encoded = (other + TABLE.lower()).replace('<', '&#60;').replace('>', '&#62;')
        router = self.router(state(encoded))
        self.assertFalse(await dhcp.reconcile(router, [RESERVATION,
            dict(name='other', mac='02:00:00:00:00:02', ip='192.168.1.4')]))
        router.async_run_service.assert_not_awaited()
        router.async_disconnect.assert_awaited_once()

    async def test_apply_owns_only_reservation_settings(self):
        router = self.router()
        router.async_api_hook.side_effect = [state(), state(TABLE)]
        self.assertTrue(await dhcp.reconcile(router, [RESERVATION]))
        router.async_run_service.assert_awaited_once_with(service="restart_dnsmasq",
            arguments={"dhcp_staticlist": TABLE, "dhcp_static_x": 1}, apply=True)

    async def test_empty_list_clears_table(self):
        router = self.router()
        router.async_api_hook.side_effect = [state(TABLE), state()]
        self.assertTrue(await dhcp.reconcile(router, []))
        self.assertEqual(router.async_run_service.call_args.kwargs['arguments']['dhcp_staticlist'], '')

    async def test_check_mode_does_not_write(self):
        router = self.router()
        self.assertTrue(await dhcp.reconcile(router, [RESERVATION], check_mode=True))
        router.async_run_service.assert_not_awaited()

    async def test_disabled_reservations_are_enabled(self):
        router = self.router()
        router.async_api_hook.side_effect = [state(TABLE, '0'), state(TABLE)]
        self.assertTrue(await dhcp.reconcile(router, [RESERVATION]))

    async def test_unreadable_state_never_writes(self):
        router = self.router({})
        with self.assertRaises(ValueError):
            await dhcp.reconcile(router, [RESERVATION])
        router.async_run_service.assert_not_awaited()
        router.async_disconnect.assert_awaited_once()

    async def test_invalid_input_never_connects(self):
        router = self.router()
        with self.assertRaises(ValueError):
            await dhcp.reconcile(router, [dict(RESERVATION, mac='bad')])
        router.async_connect.assert_not_awaited()

    async def test_rejected_update_is_reported(self):
        router = self.router()
        router.async_run_service.return_value = False
        with self.assertRaises(ValueError):
            await dhcp.reconcile(router, [RESERVATION])
        router.async_disconnect.assert_awaited_once()

    async def test_readback_mismatch_is_reported(self):
        router = self.router()
        with patch.object(dhcp.asyncio, 'sleep', new_callable=AsyncMock), self.assertRaises(ValueError):
            await dhcp.reconcile(router, [RESERVATION])
        router.async_disconnect.assert_awaited_once()

    async def test_login_failure(self):
        router = self.router()
        router.async_connect.return_value = False
        with self.assertRaises(ValueError):
            await dhcp.reconcile(router, [RESERVATION])
        router.async_run_service.assert_not_awaited()
        router.async_disconnect.assert_awaited_once()


if __name__ == '__main__':
    unittest.main()
