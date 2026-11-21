"""Offline validation and transaction tests for Merlin DNS."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('merlin_dnsmasq', Path(__file__).resolve().parents[1] / 'library/merlin_dnsmasq.py')
dns = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dns)


class DNSConfigTests(unittest.TestCase):
    def test_exact_and_wildcard(self):
        self.assertEqual(dns.render(['yusufali.ca', '*.yusufali.ca', 'yusufali.ca'], '192.168.1.4'),
                         'address=/*.yusufali.ca/192.168.1.4\nlocal=/*.yusufali.ca/\nhost-record=yusufali.ca,192.168.1.4')

    def test_rejects_invalid_input(self):
        for name in ['example.com\nserver=1.1.1.1', '#', '*example.com', '-bad.example', 'a/evil']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                dns.render([name], '192.168.1.4')
        with self.assertRaises(ValueError):
            dns.render(['example.com'], 'not-an-ip')

    def test_preserves_unmanaged_text(self):
        original = '# user config\nlog-queries\n'
        configured = dns.merge(original, 'host-record=example.com,192.168.1.4')
        self.assertTrue(configured.startswith(original))
        self.assertEqual(dns.merge(configured, ''), original)
        self.assertEqual(dns.merge(configured, 'host-record=example.com,192.168.1.4'), configured)
        with self.assertRaises(ValueError):
            dns.merge(dns.BEGIN + '\n', 'new')

    def run_reconcile(self, current='', setting='0', check=False, fail=False):
        commands = []
        self.commands = commands
        body = dns.render(['example.com'], '192.168.1.4')
        desired = dns.merge(current, body)
        state = {'setting': setting, 'restart_failed': False}

        def execute(client, command, data=None):
            commands.append((command, data))
            if command == 'nvram get jffs2_scripts':
                return state['setting']
            if command.startswith('if [ -f '):
                return current
            if command == 'cat /etc/dnsmasq.conf':
                return 'no-resolv\n' + current
            if command.startswith('dnsmasq --test') and fail is True:
                raise ValueError('syntax failure')
            if command == 'service restart_dnsmasq' and fail == 'restart' and not state['restart_failed']:
                state['restart_failed'] = True
                raise ValueError('restart failure')
            if command == 'nvram set jffs2_scripts=1 && nvram commit':
                state['setting'] = '1'
            if 'echo ANSIBLE-PID' in command:
                return 'no-resolv\n' + desired + 'ANSIBLE-PID\n1234\n'
            if command == 'cat ' + dns.PATH:
                return desired
            return ''

        with patch.object(dns, 'execute', side_effect=execute), patch.object(dns.time, 'sleep'):
            result = dns.reconcile(None, body, check)
        return result, commands

    def test_missing_file_and_disabled_jffs(self):
        changed, commands = self.run_reconcile()
        self.assertTrue(changed)
        self.assertTrue(any('mkdir -p /jffs/configs' in c for c, _ in commands))
        self.assertIn(('nvram set jffs2_scripts=1 && nvram commit', None), commands)
        self.assertIn(('service restart_dnsmasq', None), commands)

    def test_idempotent(self):
        current = dns.merge('', dns.render(['example.com'], '192.168.1.4'))
        changed, commands = self.run_reconcile(current=current, setting='1')
        self.assertFalse(changed)
        self.assertEqual(len(commands), 2)

    def test_check_mode_does_not_write(self):
        changed, commands = self.run_reconcile(check=True)
        self.assertTrue(changed)
        self.assertEqual(len(commands), 2)

    def test_validation_failure_does_not_install(self):
        with self.assertRaisesRegex(ValueError, 'syntax failure'):
            self.run_reconcile(fail=True)
        self.assertFalse(any('mkdir -p /jffs' in c for c, _ in self.commands))

    def test_restart_failure_restores_previous_file_and_jffs(self):
        with self.assertRaisesRegex(ValueError, 'restart failure'):
            self.run_reconcile(current='log-queries\n', fail='restart')
        self.assertTrue(any('/original /jffs/configs/dnsmasq.conf.add' in c for c, _ in self.commands))
        self.assertIn(('nvram set jffs2_scripts=0 && nvram commit', None), self.commands)
        self.assertEqual(sum(c == 'service restart_dnsmasq' for c, _ in self.commands), 2)


if __name__ == '__main__':
    unittest.main()
