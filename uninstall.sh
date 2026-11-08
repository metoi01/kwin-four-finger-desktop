#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Mert Okhan
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Removes the script and effect and puts KWin's gesture/animation settings
# back to their Plasma defaults (Overview + Window Aperture).
set -euo pipefail

kwin() {
    dbus-send --session --print-reply --dest=org.kde.KWin "$@" >/dev/null 2>&1 || true
}

echo "Unloading from KWin ..."
kwin /Scripting org.kde.kwin.Scripting.unloadScript string:fourfingerdesktop
rm -rf "${XDG_RUNTIME_DIR:-/tmp}"/fourfingerdesktop-session-*
kwin /Effects org.kde.kwin.Effects.unloadEffect string:slidedowndesktop

echo "Removing packages ..."
kpackagetool6 --type KWin/Script --remove fourfingerdesktop >/dev/null 2>&1 || true
kpackagetool6 --type KWin/Effect --remove slidedowndesktop >/dev/null 2>&1 || true

echo "Restoring default KWin settings ..."
# Deleting the keys makes KWin fall back to each plugin's default.
for key in fourfingerdesktopEnabled slidedowndesktopEnabled overviewEnabled \
           windowapertureEnabled eyeonscreenEnabled windowviewEnabled; do
    kwriteconfig6 --file kwinrc --group Plugins --key "$key" --delete
done

kwin /KWin org.kde.KWin.reconfigure
kwin /Effects org.kde.kwin.Effects.loadEffect string:overview
kwin /Effects org.kde.kwin.Effects.loadEffect string:windowaperture

echo "Done. Plasma's default 4-finger gestures (Overview / Grid) are back."
