#!/usr/bin/python
"""Manage ASUS DHCP reservations through the AsusRouter API."""

import asyncio
import re
from ipaddress import IPv4Address, IPv4Network

from aiohttp import ClientSession
from ansible.module_utils.basic import AnsibleModule
from asusrouter import AsusRouter

TABLE_KEY = "dhcp_staticlist"
STATE_KEY = "dhcp_static_x"
READ_KEYS = (TABLE_KEY, STATE_KEY, "lan_ipaddr", "lan_netmask")


def decode_table(value):
    value = re.sub(r"&#0*60;?", "<", value)
    return re.sub(r"&#0*62;?", ">", value)


def parse_table(value):
    rows = []
    for entry in decode_table(value).split("<"):
        if not entry:
            continue
        fields = entry.split(">")
        if not 2 <= len(fields) <= 4:
            raise ValueError("Router returned an unsupported DHCP reservation format")
        fields += [""] * (4 - len(fields))
        mac, ip, dns, name = fields
        rows.append((mac.upper(), ip, dns, name))
    return rows


def validate_reservations(reservations):
    seen_macs, seen_ips, seen_names = set(), set(), set()
    for row in reservations:
        mac = row["mac"].upper()
        if not re.fullmatch(r"(?:[0-9A-F]{2}:){5}[0-9A-F]{2}", mac):
            raise ValueError("Reservation MAC addresses must use six colon-separated hexadecimal bytes")
        if int(mac[:2], 16) & 1 or mac == "00:00:00:00:00:00":
            raise ValueError("Reservation MAC addresses must be nonzero unicast addresses")
        ip = str(IPv4Address(row["ip"]))
        name = row.get("name", "")
        if name and not re.fullmatch(r"[A-Za-z0-9_](?:[A-Za-z0-9_-]{0,30}[A-Za-z0-9_])?", name):
            raise ValueError("Reservation names must be hostnames of at most 32 characters, or empty")
        if mac in seen_macs or ip in seen_ips or (name and name.lower() in seen_names):
            raise ValueError("Reservation MAC addresses, IP addresses, and nonempty names must be unique")
        if row.get("dns") is not None and row["dns"]:
            IPv4Address(row["dns"])
        seen_macs.add(mac)
        seen_ips.add(ip)
        if name:
            seen_names.add(name.lower())


def compile_table(reservations, current, lan_ip, netmask):
    validate_reservations(reservations)
    network = IPv4Network(f"{lan_ip}/{netmask}", strict=False)
    current_dns = {mac: dns for mac, _, dns, _ in parse_table(current)}
    result = ""
    for row in reservations:
        ip = IPv4Address(row["ip"])
        if ip not in network or ip in (network.network_address, network.broadcast_address, IPv4Address(lan_ip)):
            raise ValueError("Reserved IPs must be usable LAN addresses and cannot be the router address")
        mac = row["mac"].upper()
        # The basic schema does not own per-device DNS overrides. Keep those
        # for retained MACs unless the caller explicitly supplies dns.
        dns = row.get("dns")
        if dns is None:
            dns = current_dns.get(mac, "")
        result += f"<{mac}>{ip}>{dns}>{row.get('name', '')}"
    return result


async def read_state(router):
    result = await router.async_api_hook(";".join(f"nvram_get({key})" for key in READ_KEYS) + ";")
    if (not isinstance(result, dict) or any(key not in result for key in READ_KEYS)
            or not isinstance(result[TABLE_KEY], str) or str(result[STATE_KEY]) not in ("0", "1")):
        raise ValueError("Router did not return readable DHCP reservations, state, and LAN settings")
    return result


async def reconcile(router, reservations, enabled=True, check_mode=False):
    validate_reservations(reservations)
    try:
        if not await router.async_connect():
            raise ValueError("Router login failed")
        current = await read_state(router)
        desired = compile_table(reservations, current[TABLE_KEY], current["lan_ipaddr"], current["lan_netmask"])
        def matches(state):
            return (sorted(parse_table(state[TABLE_KEY])) == sorted(parse_table(desired))
                    and str(state[STATE_KEY]) == str(int(enabled)))
        changed = not matches(current)
        if changed and not check_mode:
            if not await router.async_run_service(
                service="restart_dnsmasq", arguments={TABLE_KEY: desired, STATE_KEY: int(enabled)}, apply=True,
            ):
                raise ValueError("Router rejected the DHCP reservation update")
            for attempt in range(5):
                if matches(await read_state(router)):
                    break
                if attempt == 4:
                    raise ValueError("Router acknowledged the DHCP update but readback did not match")
                await asyncio.sleep(2)
        return changed
    finally:
        await router.async_disconnect()


async def configure(params, check_mode):
    async with ClientSession() as session:
        router = AsusRouter(session=session, **{key: params[key] for key in (
            "hostname", "username", "password", "port", "use_ssl"
        )})
        return await reconcile(router, params["reservations"], params["enabled"], check_mode)


def main():
    module = AnsibleModule(argument_spec={
        "hostname": {"type": "str", "required": True},
        "username": {"type": "str", "required": True, "no_log": True},
        "password": {"type": "str", "required": True, "no_log": True},
        "port": {"type": "int", "default": 80},
        "use_ssl": {"type": "bool", "default": False},
        "enabled": {"type": "bool", "default": True},
        "reservations": {"type": "list", "elements": "dict", "required": True, "options": {
            "name": {"type": "str", "default": ""},
            "ip": {"type": "str", "required": True},
            "mac": {"type": "str", "required": True},
            "dns": {"type": "str"},
        }},
    }, supports_check_mode=True)
    try:
        if any(not module.params[key] for key in ("hostname", "username", "password")):
            raise ValueError("Router hostname, username, and password are required")
        if not 1 <= module.params["port"] <= 65535:
            raise ValueError("Router management port must be between 1 and 65535")
        changed = asyncio.run(configure(module.params, module.check_mode))
    except Exception as exc:
        module.fail_json(msg=f"DHCP reservation reconciliation failed: {exc}")
    module.exit_json(changed=changed, reservation_count=len(module.params["reservations"]))


if __name__ == "__main__":
    main()
