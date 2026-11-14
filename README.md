# OnPrem K8s

Full iac configuration for onpremise k8s cluster.

## Configurations

- [NFS Shares](./charts/bootstrap/values.yaml#L133) for storage.
- [nodes][2]
- [router][1] reservations and portforwards

## Installation From Scratch

### PreRequisites

We assume the following:

- storage cluster has been configured and reserved static ip at 192.168.1.3
- tailscale setup completed on pikvm and secrets added to GitHub. PiKVM is static at 192.168.1.6
  - GitHub Actions has the secrets for tailscale. `TS_HOSTNAME`, `TS_OAUTH_CLIENT_ID`, and `TS_OAUTH_SECRET`
- router configured for 192.168.1.1 and dhcp to start at 192.168.1.51. leaving 192.168.1.2 - 192.168.1.49 available for dhcp reservations
- [router ansible playbooks](./ansible/router/) support the router being used for all the required [router configurations][1]
- dns is configured already for 192.168.1.50
- k8s nodes are installed with `ubuntu` user, same password
  - secrets configured in GitHub Actions: `SSH_PASSWORD`, `ID_RSA`, and `ID_RSA_PUB`

### Steps

0. Make sure all configurations are updated
1. Run the Ansible `Install` workflow.
2. Make sure OpenBao vault is working, portforward and add the cloudflare secret at `onprem/vendor/cloudflare` the required [properties](./charts/bootstrap/templates/plugin-certmanager.yaml#L47-L61).

- To get the credential for OpenBao, run `kubectl -n system-vault get secret openbao-onpremise-credentials -o go-template='username: {{index .data "username" | base64decode}}{{"\n"}}password: {{index .data "password" | base64decode}}{{"\n"}}'`
- port-forward: `kubectl -n system-vault port-forward svc/openbao-public 8200:8200`

3. Seed Authelia with the required secrets:

- onprem/vendor/authelia: hmac-secret, jwks-private, jwks-public
- onprem/authelia/yusuf: displayname, email, groups, password
- onprem/vendor/smtp

4. Once cloudflare has resolved and the ingress works, go to OpenBao and login using OIDC and add the remaining required secrets at `onprem/vendor`.
5. Backup openbao unseal key.

### Backup OpenBao Unseal Key

The openbao unseal key is required for unsealing the keyvault in the event of a restore. Export it and toss it in the B2 storage for safe keeping.

```
kubectl -n system-vault get secret openbao-unseal-key -o yaml > openbao-unseal-key.yaml
```

## Common Tasks

### Adding Nodes

Make sure the node is installed with ubuntu user and same password. Then simply update the [inventory][2] and router [DHCP reservation][1] and the ansible provider should add the node to the cluster

### Rotate Tokens/Passwords

We may need to rotate passwords. Some passwords cannot be changed by just editing the value in OpenBao, we will need to delete the password in k8s to trigger a rotation/regen of the password.

| name              | command                                                               | regenerated credentials                                     |
| ----------------- | --------------------------------------------------------------------- | ----------------------------------------------------------- |
| OpenBao onpremise | `kubectl -n system-vault delete secret openbao-onpremise-credentials` | Password for the `onpremise` user                           |
| OpenBao admin     | `kubectl -n system-vault delete secret openbao-admin-credentials`     | Password used as the managed `openbao-admin` token ID       |
| Docker mirror     | `kubectl -n kube-platform delete secret docker-mirror-credentials`    | Both username and password, plus the derived htpasswd entry |
| MinIO root        | `kubectl -n kube-platform delete secret minio-credentials`            | Both root username/access key and password/secret key       |

[1]: ./charts/platform/values.yaml#L37
[2]: ./inventory/sample/inventory.ini
