#!/usr/bin/env bash
set -euo pipefail

# Steam Headless sources this after reconciling the user and populating the home.
# Recreate directories here because a PVC can hide the image's home directory.

install -d -m 0755 -o "${PUID:?}" -g "${PGID:?}" \
    "${USER_HOME:?}" \
    "$USER_HOME/.config" \
    "$USER_HOME/.config/PCSX2" \
    "$USER_HOME/.config/PCSX2/bios" \
    "$USER_HOME/.config/dolphin-emu" \
    "$USER_HOME/.config/mupen64plus" \
    "$USER_HOME/.local" \
    "$USER_HOME/.local/share" \
    "$USER_HOME/.local/share/dolphin-emu" \
    "$USER_HOME/.local/share/mupen64plus" \
    "$USER_HOME/.cache"

# The template supplies coder_agent.main.init_script and its matching token as
# environment variables. Upstream clears the environment before starting systemd,
# so keep the bootstrap in a private, ephemeral file for the agent service.
install -d -m 0700 -o "${PUID:?}" -g "${PGID:?}" /run/steam-headless/coder-agent
if [[ -n "${CODER_AGENT_INIT_SCRIPT:-}" ]]; then
    if [[ -z "${CODER_AGENT_TOKEN:-}" ]]; then
        echo "CODER_AGENT_TOKEN is required with CODER_AGENT_INIT_SCRIPT." >&2
        exit 1
    fi
    install -m 0600 -o "${PUID:?}" -g "${PGID:?}" /dev/null /run/steam-headless/coder-agent/bootstrap
    {
        printf 'export CODER_AGENT_TOKEN=%q\n' "$CODER_AGENT_TOKEN"
        printf '%s\n' "$CODER_AGENT_INIT_SCRIPT"
    } > /run/steam-headless/coder-agent/bootstrap
else
    rm -f /run/steam-headless/coder-agent/bootstrap
fi
