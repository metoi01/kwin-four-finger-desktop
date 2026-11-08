/*
    SPDX-FileCopyrightText: 2026 Mert Okhan
    SPDX-License-Identifier: GPL-2.0-or-later

    Four Finger Switcher — a declarative (QML) KWin effect.

    4-finger swipe left/right on the touchpad shows a strip of live window
    thumbnails; the target window is the large centre card. Swiping further
    advances the selection (max 4 steps); lifting the fingers switches.

    This file is a deliberately thin, stable shell. KWin keeps ONE shared QML
    engine that caches components by URL, so after an upgrade a reload would
    keep running the old code. The real logic (Switcher.qml) and the overlay
    (Overlay.qml) are therefore loaded through URLs with a cache-busting query.
*/
import QtQuick
import org.kde.kwin as KWinComponents

KWinComponents.SceneEffect {
    id: effect

    // Unique per load of this effect, makes every reload read fresh files.
    readonly property string build: String(Date.now())
    property var switcher: null

    delegate: Loader {
        focus: true
        Component.onCompleted: setSource(Qt.resolvedUrl("Overlay.qml") + "?v=" + effect.build, {
            "switcher": effect.switcher,
            "screen": KWinComponents.SceneView.screen
        })
        Keys.onEscapePressed: {
            if (effect.switcher) {
                effect.switcher.cancel();
            }
        }
    }

    Component.onCompleted: {
        const component = Qt.createComponent(Qt.resolvedUrl("Switcher.qml") + "?v=" + build);
        if (component.status === Component.Ready) {
            switcher = component.createObject(effect, { "effect": effect });
        } else {
            console.warn("FFSW cannot load Switcher.qml:", component.errorString());
        }
    }
}
