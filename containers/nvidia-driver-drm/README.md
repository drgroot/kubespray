# NVIDIA driver with DRM/KMS

Extends the official `580.126.09-ubuntu24.04` GPU Operator driver image. The
upstream installer disables DRM; this image includes `nvidia-drm`, loads it with
`modeset=1 fbdev=0`, and unloads it before the dependent NVIDIA modules. It waits
if DRM is still in use instead of forcing a module unload.

The `modern` NVIDIADriver resource selects this image for `kube0`. The Operator
continues to build the modules for the node's kernel and manage GPU workload
eviction and driver upgrades. No host driver installation or manual module load
is required. `fbdev=0` avoids assigning the host console to the headless GPU.

The container build workflow publishes tag `580.126.09-ubuntu24.04`. Update
`DRIVER_VERSION`, `build.json`, and the driver version in the bootstrap values
together when upgrading. A rollout restarts GPU workloads on the selected node.

The build workflow discovers this directory and uses the `kernel-check` target
to compile `nvidia-drm.ko` for the `kernel-version` in `build.json` before
publishing. This check never loads modules or alters a running GPU driver.
