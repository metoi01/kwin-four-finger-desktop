/*
    SPDX-FileCopyrightText: 2026 Mert Okhan
    SPDX-License-Identifier: GPL-2.0-or-later

    Overlay of the Four Finger Switcher effect, one instance per screen.
    Draws a scrim on every screen and the "detent strip" (live thumbnails with
    the target window as the large centre card, caption pill, step notches)
    on the screen of the active window. All state comes from Switcher.qml.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kwin as KWinComponents
import org.kde.kirigami as Kirigami

Item {
    id: root

    // Provided by main.qml through Loader.setSource.
    property var switcher: null
    property var screen: null

    readonly property bool primary: switcher !== null
        && (switcher.screenName === "" || (screen !== null && switcher.screenName === screen.name))

    // --- metrics (all derived from the screen size, see the design spec) ---
    readonly property real fw: width * 0.43          // focus box
    readonly property real fh: height * 0.43
    readonly property real nScale: 0.52              // neighbour scale
    readonly property real nw: fw * nScale
    readonly property real gap: 40
    readonly property real cy: height * 0.4375       // focus box vertical centre
    readonly property real slot1: fw / 2 + gap + nw / 2
    readonly property real pitchFar: nw + gap

    // Strip position in card units: the animated step plus the lean.
    property real pos: switcher ? switcher.step : 0
    Behavior on pos {
        NumberAnimation {
            duration: root.switcher ? root.switcher.ms(180) : 0
            easing.type: Easing.OutCubic
        }
    }
    readonly property real stripPos: pos + (switcher ? switcher.lean : 0)

    // End-of-reach overshoot, in pixels along the swipe direction.
    property real kick: 0

    readonly property var focusWin: switcher ? switcher.windowAt(switcher.step) : null
    readonly property bool lowContrast:
        contrast(Kirigami.Theme.textColor, Kirigami.Theme.backgroundColor) < 4.5

    function tr(text) {
        return typeof i18nd === "function" ? i18nd("kwin", text) : text;
    }

    function lin(c) {
        return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }

    function luminance(color) {
        return 0.2126 * lin(color.r) + 0.7152 * lin(color.g) + 0.0722 * lin(color.b);
    }

    function contrast(a, b) {
        const la = luminance(a);
        const lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Horizontal offset of a card centre from the screen centre for a card
    // that is `d` slots away from the focus.
    function xOf(d) {
        const a = Math.abs(d);
        const x = a <= 1 ? a * slot1 : slot1 + (a - 1) * pitchFar;
        return d < 0 ? -x : x;
    }

    function scaleOf(d) {
        const a = Math.abs(d);
        return a >= 1 ? nScale : 1 - (1 - nScale) * a;
    }

    // Focus 1.0, slot 1 0.75, slot 2 0.40, nothing from slot 3 on.
    function opacityOf(d) {
        const a = Math.abs(d);
        if (a <= 1) {
            return 1 - 0.25 * a;
        }
        if (a <= 2) {
            return 0.75 - 0.35 * (a - 1);
        }
        return a < 3 ? 0.40 * (3 - a) : 0;
    }

    opacity: switcher ? switcher.overlayOpacity : 1

    // Backdrop: no blur, the real windows stay faintly visible.
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.62)
    }

    Item {
        id: content
        anchors.fill: parent
        visible: root.primary

        // Appear: the whole strip scales 0.97 -> 1.0, visible from frame one.
        NumberAnimation on scale {
            id: appear
            from: 0.97
            to: 1.0
            duration: root.switcher ? root.switcher.ms(120) : 0
            easing.type: Easing.OutCubic
            running: root.switcher !== null && root.switcher.ms(120) > 0
        }

        Repeater {
            model: 13

            delegate: Item {
                id: slot

                required property int index
                readonly property int k: index - 6
                readonly property real d: k - root.stripPos
                readonly property var win: root.switcher ? root.switcher.windowAt(k) : null
                readonly property bool beyond: root.switcher !== null && Math.abs(k) > root.switcher.reach
                readonly property bool live: win !== null && Math.abs(d) < 3
                readonly property real cardOpacity: Math.min(root.opacityOf(d), beyond ? 0.25 : 1)
                readonly property bool isLast: win !== null && root.switcher.windows.length > 1
                    && root.switcher.windows.indexOf(win) === root.switcher.windows.length - 1

                z: 10 - Math.abs(d)

                Item {
                    id: card
                    visible: slot.live && slot.cardOpacity > 0
                    width: root.fw
                    height: root.fh
                    x: root.width / 2 + root.xOf(slot.d) + root.kick - width / 2
                    y: root.cy - height / 2
                    scale: root.scaleOf(slot.d)
                    opacity: slot.cardOpacity

                    readonly property real gw: slot.win ? Math.max(0, slot.win.frameGeometry.width) : 0
                    readonly property real gh: slot.win ? Math.max(0, slot.win.frameGeometry.height) : 0
                    readonly property bool hasGeometry: gw > 0 && gh > 0
                    readonly property real fit: hasGeometry ? Math.min(width / gw, height / gh) : 1
                    readonly property real tw: hasGeometry ? gw * fit : width
                    readonly property real th: hasGeometry ? gh * fit : Math.min(height, width * 10 / 16)
                    readonly property bool minimized: slot.win !== null && slot.win.minimized

                    // Selection frame, only on the focus card.
                    Kirigami.ShadowedRectangle {
                        anchors.centerIn: parent
                        width: card.tw + 20
                        height: card.th + 20
                        radius: 12
                        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                        border.width: 3
                        border.color: Kirigami.Theme.highlightColor
                        shadow.size: 28
                        shadow.yOffset: 6
                        shadow.color: Qt.alpha(Qt.darker(Kirigami.Theme.backgroundColor, 3.0), 0.35)
                        opacity: Math.max(0, 1 - Math.abs(slot.d))
                    }

                    // Stand-in when the window has no usable geometry/texture.
                    Rectangle {
                        anchors.centerIn: parent
                        visible: !card.hasGeometry
                        width: card.tw
                        height: card.th
                        color: Kirigami.Theme.alternateBackgroundColor

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 96
                            height: 96
                            source: slot.win ? slot.win.icon : ""
                            fallback: "application-x-executable"
                        }
                    }

                    Loader {
                        anchors.centerIn: parent
                        width: card.tw
                        height: card.th
                        active: slot.live && card.hasGeometry
                        opacity: card.minimized ? 0.55 : 1

                        sourceComponent: KWinComponents.WindowThumbnail {
                            wId: slot.win.internalId
                        }
                    }

                    // Minimized badge, top-right of the thumbnail.
                    Rectangle {
                        visible: card.minimized
                        x: (card.width + card.tw) / 2 - width - 8
                        y: (card.height - card.th) / 2 + 8
                        width: 24
                        height: 24
                        radius: 12
                        color: Kirigami.Theme.backgroundColor

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: "window-minimize"
                        }
                    }
                }

                // App icon under each neighbour (not under the focus card, not
                // beyond this swipe's reach).
                Kirigami.Icon {
                    visible: card.visible && !slot.beyond
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    x: root.width / 2 + root.xOf(slot.d) + root.kick - width / 2
                    y: root.cy + root.fh * root.scaleOf(slot.d) / 2 + 10
                    opacity: slot.cardOpacity * Math.min(1, Math.abs(slot.d))
                    source: slot.win ? slot.win.icon : ""
                    fallback: "application-x-executable"
                }

                // Seam marker after the last window of the taskbar order.
                Rectangle {
                    readonly property real right: root.xOf(slot.d) + root.fw * root.scaleOf(slot.d) / 2
                    readonly property real left: root.xOf(slot.d + 1) - root.fw * root.scaleOf(slot.d + 1) / 2
                    visible: slot.isLast && Math.abs(slot.d + 0.5) < 2.5
                    width: 2
                    height: root.fh * root.nScale * 0.4
                    x: root.width / 2 + (right + left) / 2 + root.kick - width / 2
                    y: root.cy - height / 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
                    opacity: root.opacityOf(slot.d + 0.5)
                }
            }
        }

        // Caption pill for the window that will be activated.
        Rectangle {
            id: pill
            visible: root.focusWin !== null
            width: Math.min(root.fw, pillRow.implicitWidth + 40)
            height: pillRow.implicitHeight + 24
            x: root.width / 2 - width / 2
            y: root.cy + root.fh / 2 + 28
            radius: height / 2
            color: Qt.alpha(Kirigami.Theme.backgroundColor, root.lowContrast ? 1.0 : 0.94)

            RowLayout {
                id: pillRow
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 12

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    source: root.focusWin ? root.focusWin.icon : ""
                    fallback: "application-x-executable"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.focusWin ? root.focusWin.caption : ""
                        elide: Text.ElideRight
                        color: Kirigami.Theme.textColor
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.focusWin
                            ? root.focusWin.resourceClass + (root.focusWin.minimized ? " · " + root.tr("Minimized") : "")
                            : ""
                        elide: Text.ElideRight
                        color: Qt.alpha(Kirigami.Theme.textColor, root.lowContrast ? 1.0 : 0.72)
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        font.weight: Font.Normal
                    }
                }
            }
        }

        // One notch per reachable step; the current step is the long one.
        RowLayout {
            id: notches
            visible: root.switcher !== null && root.switcher.reach > 0
            spacing: 8
            x: root.width / 2 - width / 2
            y: pill.y + pill.height + 14

            Repeater {
                model: root.switcher ? root.switcher.reach : 0

                delegate: Rectangle {
                    required property int index
                    Layout.alignment: Qt.AlignVCenter
                    readonly property bool current: root.switcher !== null && Math.abs(root.switcher.step) === index + 1
                    width: current ? 18 : 6
                    height: 6
                    radius: 3
                    color: current ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.35)

                    Behavior on width {
                        NumberAnimation {
                            duration: root.switcher ? root.switcher.ms(180) : 0
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Text {
                visible: root.switcher !== null && root.switcher.extra > 0
                Layout.alignment: Qt.AlignVCenter
                leftPadding: 2
                text: root.switcher ? "+" + root.switcher.extra : ""
                color: Qt.alpha(Kirigami.Theme.textColor, root.lowContrast ? 1.0 : 0.72)
                font.family: Kirigami.Theme.smallFont.family
                font.pointSize: Math.max(9, Kirigami.Theme.smallFont.pointSize)
                font.weight: Font.Medium
            }
        }
    }

    // End of reach: 8 px overshoot in the travel direction and back, 220 ms.
    SequentialAnimation {
        id: overshoot
        NumberAnimation {
            target: root
            property: "kick"
            to: root.switcher ? -8 * root.switcher.overshootSign : 0
            duration: root.switcher ? root.switcher.ms(80) : 0
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "kick"
            to: 0
            duration: root.switcher ? root.switcher.ms(140) : 0
            easing.type: Easing.OutBack
        }
    }

    Connections {
        target: root.switcher
        function onOvershootTickChanged() {
            if (root.switcher.ms(220) > 0) {
                overshoot.restart();
            }
        }
    }
}
