"""Emit the JSON recap required by provider-ansible's CheckWhenObserve policy.

Only recap counts are needed for change detection. Task results, which may
contain credentials, remain in ansible-runner's protected event artifacts.
"""

import json

from ansible.plugins.callback import CallbackBase


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "stdout"
    CALLBACK_NAME = "crossplane_json"

    def v2_playbook_on_stats(self, stats):
        self._display.display(json.dumps({
            "plays": [],
            "stats": {
                host: stats.summarize(host) for host in stats.processed
            },
        }))
