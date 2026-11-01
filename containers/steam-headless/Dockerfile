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

FROM josh5/steam-headless:latest
USER root

# The latest upstream image is Fedora. Gopher64 also needs fontconfig at runtime.
RUN dnf install -y --setopt=install_weak_deps=False dolphin-emu fontconfig \
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
COPY --chmod=755 emulator-launcher /usr/local/bin/emulator-launcher
COPY --chmod=755 init-emulators.sh /usr/local/sh-init.d/95-configure_emulators.sh
COPY --chmod=755 start-coder-agent /usr/local/bin/start-coder-agent
COPY --chmod=755 start-steam-headless /usr/local/bin/start-steam-headless
COPY coder-agent.service /etc/systemd/system/coder-agent.service
COPY steam-local-runtime.conf /etc/systemd/system/steam-headless-steam.service.d/20-local-runtime.conf
COPY pcsx2.desktop /usr/share/applications/pcsx2.desktop
COPY gopher64.desktop /usr/share/applications/gopher64.desktop

ENV PUID=1000 \
    PGID=1000 \
    USER_HOME=/home/steamheadless \
    XDG_CONFIG_HOME=/home/steamheadless/.config \
    XDG_DATA_HOME=/home/steamheadless/.local/share \
    XDG_CACHE_HOME=/home/steamheadless/.cache

RUN ln -s emulator-launcher /usr/local/bin/pcsx2 \
    && ln -s emulator-launcher /usr/local/bin/dolphin-emu \
    && ln -s emulator-launcher /usr/local/bin/gopher64 \
    && sed -i -E 's|^(Exec=)(/usr/bin/)?dolphin-emu|\1/usr/local/bin/dolphin-emu|' \
        /usr/share/applications/dolphin-emu.desktop \
    && /usr/local/sh-init.d/95-configure_emulators.sh \
    && systemctl enable coder-agent.service

# Select the NVIDIA render node before upstream prepares the desktop environment.
# Keep upstream's root/systemd initialization and optional Coder agent service.
CMD ["/usr/local/bin/start-steam-headless"]
