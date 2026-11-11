ASUS router configuration
=========================

The platform Helm chart creates a dedicated Crossplane AnsibleRun when
``crossplane.enabled``, ``crossplane.ansible.enabled``, and ``router.enabled``
are true. The provider must have network access to the router's LAN management
address and Python 3.11+ with venv/pip support. Its isolated environment installs
``asusrouter==1.21.3`` from PyPI; no SSH access to the router is needed.

The chart creates an ExternalSecret backed by the ``external-infra``
ClusterSecretStore at ``vendor/router``. It synchronizes the ``ip``,
``username``, and ``password`` properties into the ``router-credentials``
Kubernetes Secret in ``argocd``. The Ansible provider reads all three properties
from that Secret, keeping the connection details out of Helm values and Git.
Override ``secretName`` and ``secretNamespace`` to change the synchronized
Secret's destination.

Add this to your platform chart values::

    router:
      enabled: true
      port: 80
      useSSL: false
      forwardingEnabled: true
      secretName: router-credentials
      secretNamespace: argocd
      dchp:
        reservations:
          - name: thorin
            ip: 192.168.1.3
            mac: 24:5E:BE:81:85:01
      portForwards:
        - name: HTTPS
          protocol: tcp
          externalPort: 443
          internalIP: 192.168.1.10
          internalPort: 443
        - name: HTTP
          protocol: tcp
          externalPort: 80
          internalIP: 192.168.1.10
          internalPort: 80

Set port and useSSL to match your router's management interface; the address
comes from the secret's ip property (192.168.1.1). These defaults match
http://192.168.1.1/Advanced_VirtualServer_Content.asp. Store only the IP address
in the ip property; AsusRouter handles the API paths.
Protocols are ``tcp``, ``udp``, or ``both``. Ports are individual integers
from 1 to 65535, and internalIP must be an IPv4 address. Overlapping protocol
and external-port combinations are rejected before connecting.

The list owns the COMPLETE forwarding table: existing entries absent from the
list are removed. An empty list clears the table. ``forwardingEnabled: false``
also switches off global port forwarding. Setting ``router.enabled: false``
or deleting the AnsibleRun leaves the last applied router configuration in
place (deletionPolicy is Orphan). To remove all rules, first reconcile an empty
list while router.enabled remains true.

The run compares the current table before writing, restarts the firewall only
when needed, and verifies the saved configuration. Rule order is ignored.
The provider's ObserveAndDelete policy applies changes when the AnsibleRun
parameters change; it does not continuously repair router drift. Credentials and the final task output are hidden with
Ansible no_log. The module supports check mode without changing the router.

The module uses the package's public async_api_hook and async_run_service
methods, NVRAM constants, and rule serializer. It applies the complete table
and global forwarding state together in a single firewall restart. The playbook
is ansible/router/playbook.yml and the modules are in ansible/router/library.
The AnsibleRun checks out crossplane.ansible.repository at its configured
revision and installs ansible/router/requirements.txt. The inventory revision
workflow also tracks changes to the router files, keeping the checkout current.

DHCP reservations
-----------------

The key ``router.dchp.reservations`` follows the spelling in the platform values.
It owns the complete reservation table: entries omitted from the list are removed,
and an empty list clears the table. Omit ``router.dchp`` entirely to leave
reservations unmanaged. Managing the table enables manual DHCP assignments
(``dhcp_static_x``); it does not change whether the DHCP server itself is enabled.

Each reservation has ``mac``, ``ip``, and an optional ``name``. An empty name
preserves an unnamed reservation. Names are saved as DHCP hostnames, not client
UI nicknames. MAC addresses, IP addresses, and nonempty names must be unique.
Reserved IPs must be usable addresses on the router's LAN, excluding the router
address itself. Input is validated before any DHCP setting is changed.

The module changes only ``dhcp_staticlist`` and ``dhcp_static_x``, then restarts
dnsmasq and verifies the saved table. That restart can briefly interrupt DNS and
DHCP service. DHCP pool boundaries, lease duration, global DNS servers, and
other router settings are preserved. Existing per-device DNS overrides are kept
for retained MAC addresses; an optional ``dns`` property can explicitly set or
clear a device's override.

The platform values include all 11 reservations from the RT-BE88U settings export.
Four entries had no hostname in the export; their supplied names in values are
retained. The backup is only used for importing reservations, never restored to
the router.

Validation
----------

Run the offline tests after installing ansible/router/requirements.txt::

    python -m unittest discover -s ansible/router/tests -v

These tests exercise serialization, validation, idempotency, additions,
removals, check mode, and router errors. They do not contact a live router.

Run directly from the repository with a YAML file containing the same router
mapping (set ROUTER_IP, ROUTER_USERNAME, and ROUTER_PASSWORD in your environment)::

    python -m pip install -r ansible/router/requirements.txt
    ansible-playbook -i localhost, ansible/router/playbook.yml -e @router-values.yaml

Add --check to preview changes without writing to the router.
