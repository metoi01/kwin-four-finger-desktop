/*
    SPDX-FileCopyrightText: 2026 Mert Okhan
    SPDX-License-Identifier: GPL-2.0-or-later

    Gesture + window-list logic of the Four Finger Switcher effect.
    Owns the two 4-finger left/right SwipeGestureHandlers and the preview state;
    Overlay.qml only draws that state.
*/
import QtQuick
import org.kde.kwin as KWinComponents
import org.kde.kirigami as Kirigami

QtObject {
    id: root

    // Tuning: swipe progress (0..1, 1.0 = 200 touchpad units) of the first
    // step, and the extra progress needed for each further step.
    readonly property real firstStep: 0.08
    readonly property real stepSize: 0.17

    // The SceneEffect that shows the overlay (set by main.qml).
    property var effect: null

    // Set to true to swap 4-finger left/right (left = previous window).
    readonly property bool invertHorizontal: false

    // Progress thresholds for steps 1..maxSteps (0.08, 0.25, ... 0.93), and how
    // far progress must fall below a threshold before the step is given up.
    readonly property int maxSteps: 6
    readonly property var thresholds: {
        const result = [];
        for (let i = 0; i < maxSteps; i++) {
            result.push(firstStep + i * stepSize);
        }
        return result;
    }
    readonly property real hysteresis: 0.04

    // --- state shared with Overlay.qml ---
    property var windows: []          // switchable windows, creation order
    property var origin: null         // the active window when the swipe began
    property int originIndex: -1      // its index in `windows`, -1 if not listed
    property int reach: 0             // how many steps this swipe can reach
    property int step: 0              // signed selected step, + = next window
    property real lean: 0             // signed pre-travel toward the next card
    property int overshootTick: 0     // bumped when the end of reach is hit
    property int overshootSign: 1
    property real overlayOpacity: 1
    property string screenName: ""    // output that draws the strip
    readonly property int extra: Math.max(0,
        (originIndex >= 0 ? windows.length - 1 : windows.length) - reach)

    // --- gesture bookkeeping ---
    property bool swiping: false
    property bool blocked: false      // nothing to switch to; swallow this swipe
    property bool suppressed: false   // cancelled with Esc; swallow the rest
    property bool shown: false
    property bool endPending: false
    property int rawLevel: 0          // 0..maxSteps, before the reach cap
    property int rawSign: 0
    property bool overshootDone: false

    // Scales a duration by Plasma's animation speed. Kirigami's longDuration is
    // 200 ms at normal speed and 0 when animations are off ("Instant").
    function ms(base) {
        return Math.round(base * Kirigami.Units.longDuration / 200);
    }

    // Windows that can be switched to: normal, shown in the switcher/taskbar,
    // on the current desktop and activity. Minimized windows are included.
    function switchableWindows() {
        const result = [];
        for (const w of KWinComponents.Workspace.windows) {
            if (!w.normalWindow || w.skipSwitcher || w.skipTaskbar) {
                continue;
            }
            const desktops = Array.from(w.desktops);
            if (!w.onAllDesktops && !desktops.includes(KWinComponents.Workspace.currentDesktop)) {
                continue;
            }
            const activities = Array.from(w.activities);
            if (activities.length !== 0 && !activities.includes(KWinComponents.Workspace.currentActivity)) {
                continue;
            }
            result.push(w);
        }
        return result;
    }

    function refresh() {
        windows = switchableWindows();
        originIndex = origin ? windows.indexOf(origin) : -1;
        reach = Math.min(maxSteps, originIndex >= 0 ? windows.length - 1 : windows.length);
    }

    // The window on the card `k` steps from the origin (circular list).
    // If the origin is not in the list, step 1 is the first window and
    // step -1 the last one; card 0 is then empty.
    function windowAt(k) {
        const n = windows.length;
        if (n === 0) {
            return null;
        }
        if (originIndex >= 0) {
            return windows[(((originIndex + k) % n) + n) % n];
        }
        if (k === 0) {
            return null;
        }
        return k > 0 ? windows[(k - 1) % n] : windows[((k % n) + n) % n];
    }

    // Step level 0..4 for a progress value, with hysteresis relative to the
    // level we are currently at.
    function levelFor(progress, current) {
        let level = current;
        while (level < maxSteps && progress >= thresholds[level]) {
            level++;
        }
        while (level > 0 && progress < thresholds[level - 1] - hysteresis) {
            level--;
        }
        return level;
    }

    function begin() {
        swiping = true;
        overshootDone = false;
        rawLevel = 0;
        rawSign = 0;
        fade.stop();
        origin = KWinComponents.Workspace.activeWindow;
        refresh();
        blocked = windows.length === 0 || (originIndex >= 0 && windows.length < 2);
        if (shown) {
            step = 0;
            lean = 0;
            overlayOpacity = 1;
        }
    }

    // sign: +1 = fingers moved left (next window), -1 = right (previous).
    function track(sign, progress) {
        endPending = false;
        if (!swiping) {
            begin();
        }
        if (blocked || suppressed) {
            return;
        }
        if (sign !== rawSign) {
            rawSign = sign;
            rawLevel = 0;
        }
        rawLevel = levelFor(progress, rawLevel);

        const level = Math.min(rawLevel, reach);
        if (!overshootDone && reach > 0 && rawLevel >= Math.min(reach + 1, maxSteps)) {
            overshootDone = true;
            overshootSign = rawSign;
            overshootTick++;
        }
        lean = (level < reach && rawLevel === level)
            ? rawSign * Math.max(0, Math.min(0.12, progress - (thresholds[level] - 0.12)))
            : 0;
        step = rawSign * level;
        if (!shown && step !== 0) {
            show();
        }
    }

    function show() {
        const output = origin && origin.output ? origin.output : KWinComponents.Workspace.activeScreen;
        screenName = output ? output.name : "";
        shown = true;
        overlayOpacity = 1;
        if (effect) {
            effect.visible = true;
        }
    }

    function hide() {
        if (!shown) {
            step = 0;
            lean = 0;
            return;
        }
        if (ms(120) === 0) {
            complete();
        } else {
            fade.restart();
        }
    }

    function complete() {
        if (effect) {
            effect.visible = false;
        }
        shown = false;
        step = 0;
        lean = 0;
        overlayOpacity = 1;
    }

    function cancel() {
        if (!swiping && !shown) {
            return;
        }
        suppressed = swiping;
        step = 0;
        lean = 0;
        hide();
    }

    // The fingers were lifted: commit or cancel.
    function finish() {
        const swallowed = blocked || suppressed;
        const target = (!swallowed && step !== 0) ? windowAt(step) : null;
        swiping = false;
        blocked = false;
        suppressed = false;
        rawLevel = 0;
        rawSign = 0;
        overshootDone = false;
        if (swallowed) {
            return;
        }
        if (target) {
            if (target.minimized) {
                target.minimized = false;
            }
            KWinComponents.Workspace.activeWindow = target;
        }
        hide();
    }

    function swipeEnded() {
        // `cancelled` is also emitted when the swipe reverses direction while
        // the fingers are still down; in that case the other handler reports
        // progress in the same event and clears endPending. Only finish once
        // nothing did, i.e. the fingers were really lifted.
        endPending = true;
        Qt.callLater(root.resetIfEnded);
    }

    function resetIfEnded() {
        if (endPending) {
            endPending = false;
            finish();
        }
    }

    // Fade-out after release (a property, as animations cannot be children here).
    property var fade: NumberAnimation {
        target: root
        property: "overlayOpacity"
        from: 1
        to: 0
        duration: root.ms(120)
        onFinished: root.complete()
    }

    // QtObject has no default property, so child objects are held in properties.
    property var windowWatcher: Connections {
        target: KWinComponents.Workspace
        function onWindowRemoved(window) {
            if (!root.swiping && !root.shown) {
                return;
            }
            if (root.origin === window) {
                root.origin = null;
            }
            root.refresh();
            root.step = Math.max(-root.reach, Math.min(root.reach, root.step));
        }
    }

    property var leftHandler: KWinComponents.SwipeGestureHandler {
        direction: KWinComponents.SwipeGestureHandler.Direction.Left
        fingerCount: 4
        deviceType: KWinComponents.SwipeGestureHandler.Device.Touchpad
        onProgressChanged: root.track(root.invertHorizontal ? -1 : 1, progress)
        onActivated: root.swipeEnded()
        onCancelled: root.swipeEnded()
    }

    property var rightHandler: KWinComponents.SwipeGestureHandler {
        direction: KWinComponents.SwipeGestureHandler.Direction.Right
        fingerCount: 4
        deviceType: KWinComponents.SwipeGestureHandler.Device.Touchpad
        onProgressChanged: root.track(root.invertHorizontal ? 1 : -1, progress)
        onActivated: root.swipeEnded()
        onCancelled: root.swipeEnded()
    }

    Component.onCompleted: console.warn("FFSW switcher loaded, longDuration=" + Kirigami.Units.longDuration)
}
