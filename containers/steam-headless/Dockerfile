# syntax=docker/dockerfile:1

FROM debian:trixie-slim AS pcsx2
ARG PCSX2_VERSION=2.8.2
ARG PCSX2_SHA256=0c46bb6a88aa2782b10853a7b07cf3387ba99cbef2b966372cd2315b8571abea
RUN test "$(dpkg --print-architecture)" = amd64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fL --retry 3 \
        "https://github.com/PCSX2/pcsx2/releases/download/v${PCSX2_VERSION}/pcsx2-v${PCSX2_VERSION}-linux-appimage-x64-Qt.AppImage" \
        -o /tmp/pcsx2.AppImage \
    && echo "${PCSX2_SHA256}  /tmp/pcsx2.AppImage" | sha256sum -c - \
    && chmod +x /tmp/pcsx2.AppImage \
    && cd /opt \
    && /tmp/pcsx2.AppImage --appimage-extract \
    && mv squashfs-root pcsx2 \
    && rm /tmp/pcsx2.AppImage

FROM debian:trixie-slim AS gopher64
ARG GOPHER64_VERSION=1.1.42
ARG GOPHER64_SHA256=1ec04481d40eab6d9d585270c08fd7d5451811d3756276364ce04998928d991d
RUN test "$(dpkg --print-architecture)" = amd64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && install -d /opt/gopher64 \
    && curl -fL --retry 3 \
        "https://github.com/gopher64/gopher64/releases/download/v${GOPHER64_VERSION}/gopher64-linux-x86_64" \
        -o /opt/gopher64/gopher64 \
    && echo "${GOPHER64_SHA256}  /opt/gopher64/gopher64" | sha256sum -c - \
    && chmod +x /opt/gopher64/gopher64

FROM debian:trixie-slim AS eden
ARG EDEN_VERSION=0.2.1
ARG EDEN_SHA256=7a28bf988b0648831989722bdbaa90ab31371b403808199813e0ea7c8b25ba6d
RUN test "$(dpkg --print-architecture)" = amd64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fL --retry 3 \
        "https://stable.eden-emu.dev/v${EDEN_VERSION}/Eden-Linux-v${EDEN_VERSION}-amd64-clang-pgo.AppImage" \
        -o /tmp/eden.AppImage \
    && echo "${EDEN_SHA256}  /tmp/eden.AppImage" | sha256sum -c - \
    && chmod +x /tmp/eden.AppImage \
    && cd /opt \
    && /tmp/eden.AppImage --appimage-extract \
    && mv "$(readlink -f squashfs-root)" eden \
    && rm /tmp/eden.AppImage

FROM debian:trixie-slim AS pince
ARG PINCE_VERSION=0.10.2
ARG PINCE_SHA256=4454664009aa4f2ada7e38971ab8d99215a917d8f3f4e2158b72d6ed4c0908b8
RUN test "$(dpkg --print-architecture)" = amd64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fL --retry 3 \
        "https://github.com/korcankaraokcu/PINCE/releases/download/v${PINCE_VERSION}/PINCE-x86_64.AppImage" \
        -o /tmp/pince.AppImage \
    && echo "${PINCE_SHA256}  /tmp/pince.AppImage" | sha256sum -c - \
    && chmod +x /tmp/pince.AppImage \
    && cd /opt \
    && /tmp/pince.AppImage --appimage-extract \
    && mv squashfs-root pince \
    && rm /tmp/pince.AppImage

FROM debian:trixie-slim AS rockstar
ARG ROCKSTAR_INSTALLER_SHA256=7bcbe2fa7e218aa740cced4e72a74e3b0f32e6a6ba7cd8228dd65f3b07f2e575
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && install -d /opt/rockstar-games-launcher \
    && curl -fL --retry 3 \
        "https://gamedownloads.rockstargames.com/public/installer/Rockstar-Games-Launcher.exe" \
        -o /opt/rockstar-games-launcher/installer.exe \
    && echo "${ROCKSTAR_INSTALLER_SHA256}  /opt/rockstar-games-launcher/installer.exe" | sha256sum -c -

FROM josh5/steam-headless:latest
USER root

# The latest upstream image is Fedora. Gopher64 also needs fontconfig at runtime.
RUN dnf install -y --setopt=install_weak_deps=False dolphin-emu fontconfig sudo \
    && dnf clean all

# The persistent NVIDIA cache can carry NFS ACLs that the container filesystem
# cannot preserve. Copy the libraries and links without those permissions/xattrs.
RUN sed -i 's/^    cp -a /    cp -a --no-preserve=mode,xattr,context /' \
    /usr/local/bin/steam-headless-provision-nvidia-compat32

COPY patch-steam-supervisor.py /usr/local/libexec/patch-steam-supervisor.py
RUN python3 /usr/local/libexec/patch-steam-supervisor.py /usr/local/bin/steam-headless-steam \
    && bash -n /usr/local/bin/steam-headless-steam

# Plasma's first launch on the persistent NFS home can exceed ten seconds.
RUN sed -i 's/for _ in {1\.\.200}; do/for _ in {1..2400}; do/' \
        /usr/local/bin/steam-headless-plasma \
    && bash -n /usr/local/bin/steam-headless-plasma

COPY --from=pcsx2 /opt/pcsx2 /opt/pcsx2
COPY --from=gopher64 /opt/gopher64 /opt/gopher64
COPY --from=eden /opt/eden /opt/eden
COPY --from=pince /opt/pince /opt/pince
COPY --from=rockstar /opt/rockstar-games-launcher /opt/rockstar-games-launcher
COPY --chmod=755 rockstar-games-launcher /usr/local/bin/rockstar-games-launcher
COPY --chmod=755 pince-launcher /usr/local/bin/pince
COPY --chmod=755 emulator-launcher /usr/local/bin/emulator-launcher
COPY --chmod=755 init-emulators.sh /usr/local/sh-init.d/95-configure_emulators.sh
COPY --chmod=755 start-coder-agent /usr/local/bin/start-coder-agent
COPY --chmod=755 start-steam-headless /usr/local/bin/start-steam-headless
COPY coder-agent.service /etc/systemd/system/coder-agent.service
COPY steam-local-runtime.conf /etc/systemd/system/steam-headless-steam.service.d/20-local-runtime.conf
COPY pcsx2.desktop /usr/share/applications/pcsx2.desktop
COPY gopher64.desktop /usr/share/applications/gopher64.desktop
COPY eden.desktop /usr/share/applications/eden.desktop
COPY pince.desktop /usr/share/applications/pince.desktop
COPY rockstar-games-launcher.desktop /usr/share/applications/rockstar-games-launcher.desktop

ENV PUID=1000 \
    PGID=1000 \
    USER_HOME=/home/steamheadless \
    XDG_CONFIG_HOME=/home/steamheadless/.config \
    XDG_DATA_HOME=/home/steamheadless/.local/share \
    XDG_CACHE_HOME=/home/steamheadless/.cache

RUN ln -s emulator-launcher /usr/local/bin/pcsx2 \
    && ln -s emulator-launcher /usr/local/bin/dolphin-emu \
    && ln -s emulator-launcher /usr/local/bin/gopher64 \
    && ln -s emulator-launcher /usr/local/bin/eden \
    && sed -i -E 's|^(Exec=)(/usr/bin/)?dolphin-emu|\1/usr/local/bin/dolphin-emu|' \
        /usr/share/applications/dolphin-emu.desktop \
    && /usr/local/sh-init.d/95-configure_emulators.sh \
    && systemctl enable coder-agent.service

# Select the NVIDIA render node before upstream prepares the desktop environment.
# Keep upstream's root/systemd initialization and optional Coder agent service.
CMD ["/usr/local/bin/start-steam-headless"]
