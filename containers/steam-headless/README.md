# Steam Headless with emulators

Uses `josh5/steam-headless:latest` as the base, with PCSX2 2.8.2 (official
AppImage, checksum verified and extracted so FUSE is unnecessary), Dolphin,
and Mupen64Plus including its plugins. Supports Linux amd64. The current upstream
latest image uses Fedora and systemd.

Startup prefers a visible NVIDIA DRM render device for both the compositor and
encoder, using the PCI vendor rather than a fixed `renderD` number. Explicit
`COMPOSITOR_RENDER_DEVICE` and `ENCODER_RENDER_DEVICE` settings take precedence.
The GPU Operator must provide the DRM/KMS-capable driver image configured in the
bootstrap chart; the stock compute driver image omits `nvidia-drm`.

Startup also restores Fedora's 64-bit NVIDIA GBM backend link when the runtime
only injects a Debian-layout link. Without it, Sunshine can select Mesa for
capture, fail NVENC initialization, and stream green frames through its Vulkan
fallback.
When NVIDIA is selected, the compositor service also uses NVIDIA's EGL vendor
explicitly. KWin's virtual backend can otherwise render on an AMD integrated GPU
despite the selected DRM device, causing PipeWire format negotiation to fail
and Moonlight to display a black screen.
The Plasma desktop shell uses Qt software rendering on NVIDIA to avoid a failed
Wayland EGL context leaving only the wallpaper visible, with no working panel
or desktop context menu. This setting is scoped to Plasma's service; games and
Sunshine retain hardware acceleration.
Plasma gets up to two minutes to register its desktop shell on the persistent
home, rather than being torn down after the upstream ten-second startup limit.

The image also adjusts upstream's Steam supervisor to tolerate runtime
extraction and updater restarts while Valve's launcher is alive. First startup
can take longer on NFS; it must not be treated as a Steam crash just because the
client binary temporarily exits during an update.

```sh
docker build --pull -t steam-headless:local containers/steam-headless
```

The existing container build workflow discovers this directory automatically.
Use `--pull` to fetch the latest base image on each build. Update `PCSX2_VERSION`
and `PCSX2_SHA256` together when upgrading PCSX2.

## Persistent configuration

Keep the upstream `steamheadless` user and persist **`/home/steamheadless`**. Its
UID/GID default to 1000 and can be changed using upstream's `PUID`/`PGID`. Startup
creates directories after mounts are attached, including on an empty home PVC,
without overwriting emulator settings.

| Emulator | Configuration | Other user data |
| --- | --- | --- |
| PCSX2 | `~/.config/PCSX2/inis` | BIOS, memory cards and save states under `~/.config/PCSX2` |
| Dolphin | `~/.config/dolphin-emu` | `~/.local/share/dolphin-emu` |
| Mupen64Plus | `~/.config/mupen64plus/mupen64plus.cfg` | `~/.local/share/mupen64plus` |

Here `~` is `/home/steamheadless`. Launch `pcsx2` or `dolphin-emu` from the desktop
menu or a terminal. Run N64 games with `mupen64plus /mnt/games/n64/game.z64`.
Configs are generated on first use. Put your PS2 BIOS dump in
`/home/steamheadless/.config/PCSX2/bios` and select it in PCSX2's first-run wizard.
Games can live on a separate `/mnt/games` mount.

## Coder integration

In your existing Kubernetes template, use this image, keep its command, and supply:

- `CODER_AGENT_INIT_SCRIPT`: the value of `coder_agent.main.init_script`.
- `CODER_AGENT_TOKEN`: the value of `coder_agent.main.token`.

The initialization hook writes the bootstrap to a private file under `/run`,
because upstream clears its environment before starting systemd. The agent
service runs as `steamheadless`, with `/home/steamheadless` as its home and working
directory, alongside the desktop services. Without the script, the agent service
is skipped. Read its logs with `journalctl -u coder-agent`.

Set the Coder agent's `dir` to `/home/steamheadless` and `arch` to `amd64`. Keep
the runtime requirements of the current upstream image, including systemd cgroup
access, the home and `/var/lib/steam-headless` persistence mounts, shared memory,
GPU resources/runtime and input devices. The older Debian StatefulSet example
uses different paths and startup options. The current UI uses port 8483; a Coder
app can proxy the UI with subdomain routing. Configure authentication and GPU
access following the current upstream documentation.

References: [Steam Headless](https://github.com/Steam-Headless/docker-steam-headless),
[Coder template tutorial](https://coder.com/docs/tutorials/template-from-scratch/).
