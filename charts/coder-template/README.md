---
display_name: Steam
description: Steam Headless with PCSX2, Dolphin, and Mupen64Plus on the on-premise NVIDIA GPU.
---

# Steam

This Coder template creates the Pod `media/steamheadless` using
`dockerhub.yusufali.ca/yusufali/steam-headless:latest`, always pulled through the
on-premise Docker mirror. CPU cores and memory in GiB are the only workspace
parameters; defaults are 4 cores and 8 GiB. The Pod requests one
`nvidia.com/gpu` allocation through the `nvidia` runtime class. With the cluster's
current time-slicing configuration, that allocation is one GPU share.

The image starts as root to initialize systemd, the desktop, and GPU services.
Its `coder-agent.service` runs the Coder agent and terminal sessions as
`steamheadless` (UID/GID 1000), with `/home/steamheadless` as the home directory.
The template preserves the image's startup command and supplies
`CODER_AGENT_INIT_SCRIPT` and `CODER_AGENT_TOKEN` for that service.

## Storage

Each workspace gets a 100 GiB PVC on `thorin-default`, named using its workspace
ID. Its `home` subdirectory mounts at `/home/steamheadless`, and its root-owned
`state` subdirectory mounts at `/var/lib/steam-headless` so appliance identity,
authentication, and TLS state survive restarts. Stopping a workspace deletes
only its Pod. Deleting the workspace also deletes its home PVC.

Games mount read/write at `/mnt/games` from the `games` subdirectory of the
existing `media-media` PVC on `thorin-nobackup`, declared in
`charts/media/values.yaml`. An init container creates the directories with the
required ownership. This template never creates or deletes the shared games PVC.
Steam's shared library lives at `/mnt/games/GameLibrary/Steam`; emulator ROMs can
also be stored under `/mnt/games`.

## Cluster requirements

Coder's existing `coder-workspace-perms` role grants `servc-infra/coder`
permissions to manage Pods and PVCs in `media`. The media chart owns the Service
and routes, so Coder needs no additional RBAC. Sync platform (gateway listeners)
and the media chart (Service and routes) before starting a workspace.
The namespace must already contain `media-media` and `cluster-docker-secrets`.
The custom image must have been published by the container build workflow.

The Pod uses its own network namespace, private writable `/dev/input` and
`/run/udev` directories, and the host's `/dev/uinput` for virtual controllers.
Its input daemon populates its own device nodes and udev database before the
desktop starts. The privileged container runs the desktop and systemd; `/run`,
`/run/udev`, and `/dev/shm` use memory-backed volumes. The NVIDIA runtime
provides GPU devices and driver libraries.

Open the owner-only **Steam** app in Coder to reach the HTTPS UI on port 8483
and complete initial setup, which enables Sunshine. Use the same app for
administration and Moonlight pairing. Sunshine's administration port 47990 is
kept inside the Pod.

## Sunshine streaming through Gateway API

The platform chart adds listeners to `system-envoy/gateway`. The media chart
owns the `media/steam-sunshine` ClusterIP Service and attaches TCPRoutes and
UDPRoutes to those listeners. Its Service selector matches the fixed
`steamheadless` label on the Pod. The listeners accept routes only from
`media`. No ReferenceGrant is needed because each route and its backend Service
are in the same namespace.

| Protocol | Ports | Purpose |
| --- | --- | --- |
| TCP | 47984, 47989, 48010 | GameStream HTTPS/HTTP, pairing, RTSP |
| UDP | 47998, 47999, 48000 | Video, control, audio |

Add an Envoy gateway node IP manually in Moonlight, such as `192.168.1.10`.
The gateway runs on the nodes and forwards these ports to the Steam Pod; the
browser UI stays behind Coder. Automatic LAN discovery does not traverse the
gateway. Streaming uses Moonlight; browser WebRTC streaming is not exposed by
these Sunshine routes.

The fixed gateway address and ports serve **one active Steam workspace**.
The fixed Pod name `steamheadless` reserves that endpoint for one workspace.
Stop the active workspace before starting a different Steam workspace.
Stopping deletes only the Pod while retaining the home PVC and shared games.
The chart-managed Service and routes remain, with no backend until the next
Steam Pod becomes ready.

Port mapping follows the [Sunshine networking documentation](https://docs.lizardbyte.dev/projects/sunshine/v0.22.2/about/advanced_usage.html#port).

## Validation and publication

`.github/workflows/coder-template.yml` formats, validates, and runs Terraform
plan tests. Same-repository PRs upload an inactive template version. Pushes to
`main` and manual runs on `main` upload a version before promoting it. The
template's display name is **Steam**, with CLI name `steam`.

The workflow authenticates to Vault using the repository secrets
`VAULT_ADDRESS`, `VAULT_USERNAME`, and `VAULT_PASSWORD`, then reads `url` and
`token` from `servc/data/iac/coder-onpremise`. No additional repository secrets
or template variables are required.

Run the local checks from this directory:

```sh
terraform fmt -check
terraform init -backend=false
terraform validate
terraform test
```

The Pod follows the GPU, games, input-device, and shared-memory requirements in
the [upstream Kubernetes example](https://github.com/Steam-Headless/docker-steam-headless/blob/master/docs/k8s-files/statefulset.yaml),
with the home path, persistent appliance state, systemd startup, and UI port
adapted for the Fedora-based custom image.
