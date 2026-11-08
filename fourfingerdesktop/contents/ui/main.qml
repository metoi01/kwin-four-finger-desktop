/*
    SPDX-FileCopyrightText: 2026 Mert Okhan
    SPDX-License-Identifier: GPL-2.0-or-later

    Four Finger Desktop — a declarative (QML) KWin script.

    4-finger swipe down -> if Window View is open, close it; otherwise show
                           the desktop (windows slide away)
    4-finger swipe up   -> if the desktop is shown, bring the windows back;
                           otherwise open Window View (Present Windows).
    4-finger swipe left/right is handled by the separate "Four Finger
    Switcher" effect (fourfingerswitcher).

    KWin's built-in Overview effect hard-codes 4-finger up/down swipes and
    KWin fires *every* gesture that matches a swipe, so the Overview effect
    must be disabled while this script is active (install.sh does that).
*/
import QtQuick
import org.kde.kwin

Item {
    id: root

    // org.kde.KWin.showDesktop(bool) — explicitly show/hide the desktop (not a toggle).
    DBusCall {
        id: setShowDesktop
        service: "org.kde.KWin"
        path: "/KWin"
        dbusInterface: "org.kde.KWin"
        method: "showDesktop"
    }

    // Is the desktop currently shown? Also correct when it was shown via Meta+D.
    DBusCall {
        id: queryShowingDesktop
        service: "org.kde.KWin"
        path: "/KWin"
        dbusInterface: "org.freedesktop.DBus.Properties"
        method: "Get"
        arguments: ["org.kde.KWin", "showingDesktop"]
        onFinished: (reply) => {
            if (reply.length > 0 && reply[0] === true) {
                root.showDesktop(false);
            } else {
                windowView.call();
            }
        }
        onFailed: windowView.call()
    }

    // Is Window View open? A swipe down closes it instead of showing the desktop.
    DBusCall {
        id: queryActiveEffects
        service: "org.kde.KWin"
        path: "/Effects"
        dbusInterface: "org.freedesktop.DBus.Properties"
        method: "Get"
        arguments: ["org.kde.kwin.Effects", "activeEffects"]
        onFinished: (reply) => {
            if (Array.from(reply[0] || []).indexOf("windowview") !== -1) {
                windowView.call();
            } else {
                root.showDesktop(true);
            }
        }
        onFailed: root.showDesktop(true)
    }

    // Window View for the current desktop — same as the Ctrl+F9 shortcut.
    DBusCall {
        id: windowView
        service: "org.kde.kglobalaccel"
        path: "/component/kwin"
        dbusInterface: "org.kde.kglobalaccel.Component"
        method: "invokeShortcut"
        arguments: ["Expose"]
    }

    function showDesktop(show) {
        setShowDesktop.arguments = [show];
        setShowDesktop.call();
    }

    function handleDown() { queryActiveEffects.call(); }
    function handleUp() { queryShowingDesktop.call(); }

    /*
        Activation threshold (0..1) — how far you have to swipe.

        1.0 is KWin's full swipe distance (200 touchpad units). We do NOT wait
        for the fingers to be lifted: the action fires the moment the swipe
        passes this threshold, so it feels instant. Raise it if you trigger
        the gesture by accident; lower it to make it even more sensitive.
    */
    readonly property real threshold: 0.1

    // True once the current swipe has fired; prevents firing twice
    // (e.g. down then back up in a single swipe).
    property bool fired: false
    // Set when a handler reports the swipe ended; cleared if the swipe goes on.
    property bool endPending: false

    function track(dir, progress) {
        endPending = false;
        if (!fired && progress >= threshold) {
            fired = true;
            dir === "down" ? handleDown() : handleUp();
        }
    }

    function swipeEnded() {
        // `cancelled` is also emitted when the swipe reverses direction while
        // the fingers are still down; in that case the other handler reports
        // progress in the same event and clears endPending. Only reset once
        // nothing did, i.e. the fingers were really lifted.
        endPending = true;
        Qt.callLater(root.resetIfEnded);
    }

    function resetIfEnded() {
        if (endPending) {
            fired = false;
            endPending = false;
        }
    }

    SwipeGestureHandler {
        direction: SwipeGestureHandler.Direction.Down
        fingerCount: 4
        deviceType: SwipeGestureHandler.Device.Touchpad
        onProgressChanged: root.track("down", progress)
        onActivated: root.swipeEnded()
        onCancelled: root.swipeEnded()
    }

    SwipeGestureHandler {
        direction: SwipeGestureHandler.Direction.Up
        fingerCount: 4
        deviceType: SwipeGestureHandler.Device.Touchpad
        onProgressChanged: root.track("up", progress)
        onActivated: root.swipeEnded()
        onCancelled: root.swipeEnded()
    }
}
