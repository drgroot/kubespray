#!/usr/bin/python
"""Reconcile the ASUS virtual-server table using asusrouter's public API."""

import asyncio
import re
from ipaddress import IPv4Address

from ansible.module_utils.basic import AnsibleModule
from asusrouter import AsusRouter
from asusrouter.modules.port_forwarding import (
    KEY_PORT_FORWARDING_LIST as RULES_KEY,
    KEY_PORT_FORWARDING_STATE as STATE_KEY,
    PortForwardingRule,
)
from asusrouter.tools.legacy import compile_port_forwarding


def compile_rules(forwards):
    rules = []
    occupied = set()
    for forward in forwards:
        name = forward["name"]
        if not name.strip() or any(c in name for c in '<>&\r\n'):
            raise ValueError("Rule names must be nonempty and cannot contain <, >, &, or newlines")
        ip = str(IPv4Address(forward["internalIP"]))
        for key in ("externalPort", "internalPort"):
            if not 1 <= forward[key] <= 65535:
                raise ValueError(f"{key} must be between 1 and 65535")
        protocol = forward["protocol"].upper()
        protocols = ("TCP", "UDP") if protocol == "BOTH" else (protocol,)
        for item in protocols:
            identity = (item, forward["externalPort"])
            if identity in occupied:
                raise ValueError("Rules cannot overlap on protocol and externalPort")
            occupied.add(identity)
        rules.append(PortForwardingRule(
            name=name, ip_address=ip, port=str(forward["internalPort"]),
            protocol=protocol, port_external=str(forward["externalPort"]),
        ))
    return compile_port_forwarding(rules)[RULES_KEY]


def normalized_rules(value):
    # hook.cgi can return numeric HTML entities with or without semicolons.
    value = re.sub(r"&#0*60;?", "<", value)
    value = re.sub(r"&#0*62;?", ">", value)
    # Firmware variants differ in the final separator. Order has no meaning.
    return sorted(rule.rstrip(">") for rule in value.split("<") if rule)


async def read_state(router):
    result = await router.async_api_hook(
        f"nvram_get({RULES_KEY});nvram_get({STATE_KEY});"
    )
    if (not isinstance(result, dict) or RULES_KEY not in result
            or str(result.get(STATE_KEY)) not in ("0", "1")
            or not isinstance(result[RULES_KEY], str)):
        raise ValueError("Router did not return a readable port forwarding table and state")
    return result


async def reconcile(router, desired, enabled, check_mode=False):
    try:
        if not await router.async_connect():
            raise ValueError("Router login failed")
        current = await read_state(router)
        changed = (normalized_rules(current[RULES_KEY]) != normalized_rules(desired)
                   or str(current[STATE_KEY]) != str(int(enabled)))
        if changed and not check_mode:
            applied = await router.async_run_service(
                service="restart_firewall",
                arguments={RULES_KEY: desired, STATE_KEY: int(enabled)},
                apply=True,
            )
            if not applied:
                raise ValueError("Router rejected the port forwarding update")
            # Firmware may acknowledge before the firewall restart completes.
            for attempt in range(5):
                actual = await read_state(router)
                if (normalized_rules(actual[RULES_KEY]) == normalized_rules(desired)
                        and str(actual[STATE_KEY]) == str(int(enabled))):
                    break
                if attempt == 4:
                    raise ValueError("Router acknowledged the update but readback did not match")
                await asyncio.sleep(2)
        return changed
    finally:
        await router.async_disconnect()


def main():
    module = AnsibleModule(
        argument_spec={
            "hostname": {"type": "str", "required": True},
            "username": {"type": "str", "required": True, "no_log": True},
            "password": {"type": "str", "required": True, "no_log": True},
            "port": {"type": "int", "default": 80},
            "use_ssl": {"type": "bool", "default": False},
            "enabled": {"type": "bool", "default": True},
            "port_forwards": {
                "type": "list", "elements": "dict", "required": True,
                "options": {
                    "name": {"type": "str", "required": True},
                    "protocol": {"type": "str", "choices": ["tcp", "udp", "both"], "required": True},
                    "externalPort": {"type": "int", "required": True},
                    "internalIP": {"type": "str", "required": True},
                    "internalPort": {"type": "int", "required": True},
                },
            },
        },
        supports_check_mode=True,
    )
    try:
        desired = compile_rules(module.params["port_forwards"])
        if not module.params["hostname"] or not module.params["username"] or not module.params["password"]:
            raise ValueError("Router hostname, username, and password are required")
        if not 1 <= module.params["port"] <= 65535:
            raise ValueError("Router management port must be between 1 and 65535")
        router = AsusRouter(**{key: module.params[key] for key in (
            "hostname", "username", "password", "port", "use_ssl"
        )})
        changed = asyncio.run(reconcile(router, desired, module.params["enabled"], module.check_mode))
    except Exception as exc:
        module.fail_json(msg=f"Port forwarding reconciliation failed: {exc}")
    module.exit_json(changed=changed, rule_count=len(module.params["port_forwards"]))


if __name__ == "__main__":
    main()
