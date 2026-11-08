/*
    SPDX-FileCopyrightText: 2015 Thomas Lübking <thomas.luebking@gmail.com>
    SPDX-FileCopyrightText: 2026 Mert Okhan
    SPDX-License-Identifier: GPL-2.0-or-later

    Slide Down Desktop — a "Show Desktop" animation for KWin.

    When the desktop is shown, open windows slide down off the screen.
    When it is hidden again, the same animation plays in reverse, so the
    windows return to their old positions and stacking order.

    Adapted from KWin's Window Aperture effect
    (/usr/share/kwin/effects/windowaperture).
*/
/*global effect, effects, animationTime, set, cancel, redirect, animate, Effect, QEasingCurve */

"use strict";

var slideDown = {
    duration: animationTime(200),
    showingDesktop: false,

    loadConfig: function () {
        slideDown.duration = animationTime(200);
    },

    // Vertical distance that moves the window's top edge to the bottom edge of its screen.
    offsetFor: function (w) {
        var screen = (w.screen && w.screen.geometry) ? w.screen.geometry : effects.virtualScreenGeometry;
        return screen.y + screen.height - w.geometry.y;
    },

    reset: function (w) {
        if (w.slideDownId) {
            cancel(w.slideDownId);
        }
        delete w.slideDownId;
        delete w.slideDownDy;
    },

    onShowingDesktopChanged: function (showing) {
        slideDown.showingDesktop = showing;
        var stack = effects.stackingOrder;

        for (var i = 0; i < stack.length; ++i) {
            var w = stack[i];
            if (w.dock || w.desktopWindow) {
                continue;
            }

            if (showing) {
                if (!w.hiddenByShowDesktop) {
                    continue;
                }
                if (!w.visible) {
                    slideDown.reset(w);
                    continue;
                }
                // Shown again while the restore animation is still running: just reverse it.
                if (w.slideDownId && redirect(w.slideDownId, Effect.Forward)) {
                    continue;
                }
                var dy = slideDown.offsetFor(w);
                w.slideDownDy = dy;
                // set(): the window stays at the target (below the screen) after the animation.
                w.slideDownId = set({
                    window: w,
                    duration: slideDown.duration,
                    curve: QEasingCurve.InOutCubic,
                    animations: [{
                        type: Effect.Translation,
                        from: { value1: 0, value2: 0 },
                        to: { value1: 0, value2: dy }
                    }]
                });
            } else {
                if (!w.slideDownId) {
                    continue;
                }
                if (!w.visible) {
                    slideDown.reset(w);
                    continue;
                }
                // Play the same animation backwards: the window rises back into place.
                if (!redirect(w.slideDownId, Effect.Backward)) {
                    var from = w.slideDownDy || slideDown.offsetFor(w);
                    slideDown.reset(w);
                    animate({
                        window: w,
                        duration: slideDown.duration,
                        curve: QEasingCurve.InOutCubic,
                        animations: [{
                            type: Effect.Translation,
                            from: { value1: 0, value2: from },
                            to: { value1: 0, value2: 0 }
                        }]
                    });
                }
            }
        }
    },

    animationEnded: function (w) {
        // Once the restore animation is done, drop the persistent (set) animation.
        if (!slideDown.showingDesktop) {
            slideDown.reset(w);
        }
    },

    init: function () {
        slideDown.loadConfig();
        effect.configChanged.connect(slideDown.loadConfig);
        effects.showingDesktopChanged.connect(slideDown.onShowingDesktopChanged);
        effect.animationEnded.connect(slideDown.animationEnded);
    }
};

slideDown.init();
