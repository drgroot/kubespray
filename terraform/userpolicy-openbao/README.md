# Additive OpenBao user policies

Each workspace publishes one ACL policy named
`openbao-userpolicy-<username>--<name>`. It accepts `username`, a unique workspace
`name`, comma-separated API `path` values, and comma-separated `capabilities`.
Paths are literal OpenBao API paths, including KV v2 endpoint segments such as
`servc/data/infra/*` and `servc/destroy/infra/*`.

The `user-openbao` module discovers policies for its exact username through
`sys/policy` and includes them alongside its base policy on the userpass account
and managed token. This workspace owns only its ACL policy. The user workspace
remains the sole owner of credentials and policy attachment lists.

Apply the policy workspace, then reconcile the user workspace to pick up a new
attachment. Crossplane's next user reconciliation also picks it up. Adding or
removing an attachment replaces the managed token and republishes its output
credentials; existing userpass sessions need a fresh login. Updating an already
attached policy's contents takes effect without changing its name or token.
Deleting the policy removes its grants immediately; the next user reconciliation
removes the obsolete attachment from the account and managed token.

The `openbao-userpolicy-` namespace is reserved for these workspaces. Usernames
cannot contain `--`, which separates the account name from the policy name.
