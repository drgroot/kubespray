"""Exercise the stdout boundary parsed by provider-ansible CheckWhenObserve."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class CrossplaneJSONCallbackTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("ansible-runner"), "ansible-runner is required")
    def test_runner_reports_changes_as_json_without_task_secrets(self):
        callback_dir = (
            Path(__file__).resolve().parents[2]
            / "charts/bootstrap/files/callback_plugins"
        )
        for changed in (False, True):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory:
                private_dir = Path(directory)
                (private_dir / "project").mkdir()
                (private_dir / "inventory").mkdir()
                # CI selects Kubespray's config, whose profiling callback adds
                # text to stdout. Model the provider's configuration instead.
                config = private_dir / "ansible.cfg"
                config.write_text("[defaults]\n")
                (private_dir / "inventory/hosts").write_text(
                    "localhost ansible_connection=local\n"
                )
                (private_dir / "project/playbook.yml").write_text(
                    "- hosts: localhost\n"
                    "  gather_facts: false\n"
                    "  tasks:\n"
                    "    - ansible.builtin.debug:\n"
                    "        msg: secret-must-not-appear-in-stdout\n"
                    "      no_log: true\n"
                    f"      changed_when: {str(changed).lower()}\n"
                )
                result = subprocess.run(
                    [
                        "ansible-runner", "run", directory,
                        "-p", "playbook.yml", "--cmdline", r"\--check",
                    ],
                    env={
                        **{
                            key: value for key, value in os.environ.items()
                            if key != "ANSIBLE_CALLBACKS_ENABLED"
                        },
                        "ANSIBLE_CONFIG": str(config),
                        "ANSIBLE_STDOUT_CALLBACK": "crossplane_json",
                        "ANSIBLE_CALLBACK_PLUGINS": str(callback_dir),
                        "ANSIBLE_NOCOLOR": "1",
                        "ANSIBLE_FORCE_COLOR": "0",
                    },
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                try:
                    summary = json.loads(result.stdout)["stats"]["localhost"]
                except json.JSONDecodeError as error:
                    self.fail(
                        f"Runner stdout must be a single JSON document: {error}\n"
                        f"stdout: {result.stdout!r}\nstderr: {result.stderr!r}"
                    )
                self.assertEqual(summary["changed"], int(changed))
                self.assertEqual(summary["failures"], 0)
                self.assertNotIn("secret-must-not-appear-in-stdout", result.stdout)


if __name__ == "__main__":
    unittest.main()
