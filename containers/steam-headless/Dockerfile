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

FROM josh5/steam-headless:latest
USER root

# The latest upstream image is Fedora. Its Mupen64Plus package includes plugins.
RUN dnf install -y --setopt=install_weak_deps=False dolphin-emu mupen64plus \
    && dnf clean all

COPY --from=pcsx2 /opt/pcsx2 /opt/pcsx2
COPY --chmod=755 emulator-launcher /usr/local/bin/emulator-launcher
COPY --chmod=755 init-emulators.sh /usr/local/sh-init.d/95-configure_emulators.sh
COPY --chmod=755 start-coder-agent /usr/local/bin/start-coder-agent
COPY coder-agent.service /etc/systemd/system/coder-agent.service
COPY pcsx2.desktop /usr/share/applications/pcsx2.desktop

ENV PUID=1000 \
    PGID=1000 \
    USER_HOME=/home/steamheadless \
    XDG_CONFIG_HOME=/home/steamheadless/.config \
    XDG_DATA_HOME=/home/steamheadless/.local/share \
    XDG_CACHE_HOME=/home/steamheadless/.cache

RUN ln -s emulator-launcher /usr/local/bin/pcsx2 \
    && ln -s emulator-launcher /usr/local/bin/dolphin-emu \
    && ln -s emulator-launcher /usr/local/bin/mupen64plus \
    && sed -i -E 's|^(Exec=)(/usr/bin/)?dolphin-emu|\1/usr/local/bin/dolphin-emu|' \
        /usr/share/applications/dolphin-emu.desktop \
    && /usr/local/sh-init.d/95-configure_emulators.sh \
    && systemctl enable coder-agent.service

# Keep upstream's root command and systemd: they initialize the desktop,
# GPU, audio, Steam, and the user before launching the optional Coder agent.
