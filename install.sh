#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Mert Okhan
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Installs the "Four Finger Desktop" KWin script and the "Slide Down Desktop"
# effect for the current user, enables them, and reloads KWin. No root needed.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KWINRC="${XDG_CONFIG_HOME:-$HOME/.config}/kwinrc"

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: '$1' was not found. This requires KDE Plasma 6." >&2
        exit 1
    }
}
need kpackagetool6
need kwriteconfig6
need dbus-send

if [ "${XDG_SESSION_TYPE:-}" != "wayland" ]; then
    echo "Warning: touchpad gestures only work in a Plasma *Wayland* session." >&2
fi

install_pkg() {
    local type="$1" path="$2"
    if ! kpackagetool6 --type "$type" --install "$path" >/dev/null 2>&1; then
        kpackagetool6 --type "$type" --upgrade "$path" >/dev/null
    fi
    echo "  installed $(basename "$path") ($type)"
}

kwin() {
    dbus-send --session --print-reply --dest=org.kde.KWin "$@" >/dev/null 2>&1 || true
}

echo "Installing packages into ~/.local/share/kwin ..."
install_pkg KWin/Effect "$DIR/slidedowndesktop"
install_pkg KWin/Script "$DIR/fourfingerdesktop"

if [ -f "$KWINRC" ]; then
    backup="$KWINRC.bak-fourfinger-$(date +%Y%m%d-%H%M%S)"
    cp "$KWINRC" "$backup"
    echo "Backed up kwinrc to $backup"
fi

echo "Updating KWin settings ..."
# The built-in Overview effect hard-codes 4-finger up/down swipes; it has to be
# off, otherwise both gestures fire at the same time.
kwriteconfig6 --file kwinrc --group Plugins --key overviewEnabled false
# Only one "Show Desktop" animation can be active at a time.
kwriteconfig6 --file kwinrc --group Plugins --key windowapertureEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key eyeonscreenEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key slidedowndesktopEnabled true
# Window View is what a 4-finger swipe up opens.
kwriteconfig6 --file kwinrc --group Plugins --key windowviewEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key fourfingerdesktopEnabled true

echo "Reloading KWin ..."
kwin /KWin org.kde.KWin.reconfigure
for effect in overview windowaperture eyeonscreen slidedowndesktop; do
    kwin /Effects org.kde.kwin.Effects.unloadEffect "string:$effect"
done
kwin /Effects org.kde.kwin.Effects.loadEffect string:windowview
kwin /Effects org.kde.kwin.Effects.loadEffect string:slidedowndesktop
# KWin caches QML components by file path, so reloading the installed main.qml
# would keep running the old code until the next login. Load a copy from a
# fresh path instead (same plugin name, so System Settings and uninstall still
# work). The copy only lives for this session; the next login loads the
# installed package normally.
kwin /Scripting org.kde.kwin.Scripting.unloadScript string:fourfingerdesktop
rm -rf "${XDG_RUNTIME_DIR:-/tmp}"/fourfingerdesktop-session-*
session_dir="${XDG_RUNTIME_DIR:-/tmp}/fourfingerdesktop-session-$(date +%s%N)"
mkdir -p "$session_dir"
cp "${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts/fourfingerdesktop/contents/ui/main.qml" "$session_dir/main.qml"
kwin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript "string:$session_dir/main.qml" string:fourfingerdesktop
kwin /Scripting org.kde.kwin.Scripting.start

echo
echo "Done! Swipe down with 4 fingers to show the desktop, swipe up to bring the windows back."
echo "To undo everything, run: $DIR/uninstall.sh"
