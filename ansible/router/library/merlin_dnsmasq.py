#!/usr/bin/python
"""Manage a bounded dnsmasq block over SSH; Merlin needs no Python or SFTP."""
import ipaddress
import re
import shlex
import time
import uuid

import paramiko
from ansible.module_utils.basic import AnsibleModule

BEGIN = '# BEGIN ANSIBLE ROUTER DNS'
END = '# END ANSIBLE ROUTER DNS'
PATH = '/jffs/configs/dnsmasq.conf.add'


def domain(value, wildcard=False):
    value = value.lower().rstrip('.')
    name = value[2:] if wildcard and value.startswith('*.') else value
    if len(name) > 253 or not all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', label)
                                  for label in name.split('.')):
        raise ValueError('Invalid DNS name: ' + value)
    return value


def render(domains, vip):
    vip = str(ipaddress.IPv4Address(vip))
    names = sorted({domain(name, wildcard=True) for name in domains})
    lines = []
    for name in names:
        if name.startswith('*.'):
            lines += [f'address=/{name}/{vip}', f'local=/{name}/']
        else:
            lines += [f'host-record={name},{vip}']
    return '\n'.join(lines)


def merge(current, body):
    if current.count(BEGIN) != current.count(END) or current.count(BEGIN) > 1:
        raise ValueError('Malformed managed block; refusing to overwrite existing configuration')
    block = BEGIN + '\n' + body + '\n' + END + '\n' if body else ''
    if BEGIN in current:
        pattern = r'(?m)^' + re.escape(BEGIN) + r'\n.*?^' + re.escape(END) + r'\n?'
        result, count = re.subn(pattern, lambda _: block, current, flags=re.S)
        if count != 1:
            raise ValueError('Malformed managed block')
        return result
    return current + ('\n' if current and not current.endswith('\n') else '') + block


def execute(client, command, data=None):
    stdin, stdout, stderr = client.exec_command(command, timeout=60)
    try:
        if data is not None:
            stdin.write(data)
            stdin.flush()
        stdin.channel.shutdown_write()
        output = stdout.read().decode()
        error = stderr.read().decode()
        if stdout.channel.recv_exit_status() != 0:
            raise ValueError('Router command failed: ' + error.strip())
        return output
    finally:
        stdin.close()
        stdout.close()
        stderr.close()


def reconcile(client, body, check_mode=False):
    setting = execute(client, 'nvram get jffs2_scripts').strip()
    current = execute(client, f'if [ -f {PATH} ]; then cat {PATH}; fi')
    desired = merge(current, body)
    # Empty desired configuration removes our block, preserving all other text.
    changed = desired != current or (bool(body) and setting != '1')
    if not changed or check_mode:
        return changed
    runtime = execute(client, 'cat /etc/dnsmasq.conf')
    # Merlin appends .add to the generated config. Remove that suffix before
    # validating the replacement against the rest of the live configuration.
    if current.strip() and setting == '1':
        index = runtime.rfind(current.rstrip())
        if index < 0 or runtime[index + len(current.rstrip()):].strip():
            raise ValueError('Existing .add content is not the runtime suffix; resolve custom postconf changes first')
        base = runtime[:index]
    else:
        base = runtime
    candidate = base.rstrip() + '\n' + desired
    work = '/tmp/ansible-dns.' + uuid.uuid4().hex
    execute(client, f'umask 077; mkdir {work}')
    installed = False
    enabled = False
    try:
        execute(client, f'cat > {work}/candidate', candidate)
        execute(client, f'dnsmasq --test --conf-file={work}/candidate')
        execute(client, f'cat > {work}/desired', desired)
        execute(client, f'mkdir -p /jffs/configs; if [ -f {PATH} ]; then cp -p {PATH} {work}/original; fi')
        execute(client, f'cp {work}/desired {PATH}.ansible-tmp && chmod 0644 {PATH}.ansible-tmp && mv {PATH}.ansible-tmp {PATH}')
        installed = True
        if body and setting != '1':
            enabled = True
            execute(client, 'nvram set jffs2_scripts=1 && nvram commit')
        execute(client, 'service restart_dnsmasq')
        for attempt in range(15):
            time.sleep(2)
            active = execute(client, 'cat /etc/dnsmasq.conf; echo ANSIBLE-PID; pidof dnsmasq || true')
            config, _, pid = active.partition('ANSIBLE-PID\n')
            if (desired.strip() in config if desired.strip() else BEGIN not in config) and pid.strip():
                execute(client, 'dnsmasq --test --conf-file=/etc/dnsmasq.conf')
                if execute(client, f'cat {PATH}') != desired:
                    raise ValueError('Persistent config readback did not match')
                if body and execute(client, 'nvram get jffs2_scripts').strip() != '1':
                    raise ValueError('JFFS setting readback did not match')
                return True
        raise ValueError('dnsmasq did not restart with the desired configuration')
    except Exception:
        if installed:
            execute(client, f'if [ -f {work}/original ]; then cp -p {work}/original {PATH}; else rm -f {PATH}; fi')
        if enabled:
            command = ('nvram set jffs2_scripts=' + shlex.quote(setting)) if setting else 'nvram unset jffs2_scripts'
            execute(client, command + ' && nvram commit')
        if installed:
            execute(client, 'service restart_dnsmasq')
        raise
    finally:
        execute(client, f'rm -rf {work}')


def main():
    module = AnsibleModule(argument_spec={
        'hostname': dict(required=True),
        'username': dict(required=True, no_log=True),
        'password': dict(required=True, no_log=True),
        'port': dict(type='int', default=1024),
        'virtual_ip': dict(required=True),
        'domains': dict(type='list', elements='str', required=True),
    }, supports_check_mode=True)
    client = paramiko.SSHClient()
    try:
        p = module.params
        body = render(p['domains'], p['virtual_ip'])
        if not 1 <= p['port'] <= 65535:
            raise ValueError('Invalid SSH port')
        # Trust this connection without persisting host keys, as requested.
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(p['hostname'], port=p['port'], username=p['username'], password=p['password'],
                       look_for_keys=False, allow_agent=False, timeout=15, auth_timeout=15, banner_timeout=15)
        changed = reconcile(client, body, module.check_mode)
    except Exception as exc:
        module.fail_json(msg=f'Merlin DNS reconciliation failed: {exc}')
    finally:
        client.close()
    module.exit_json(changed=changed)


if __name__ == '__main__':
    main()
