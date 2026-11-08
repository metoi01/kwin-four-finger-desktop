# Four Finger Desktop for KDE Plasma

**Swipe down with four fingers to see your desktop. Swipe up to get your windows back.**

A small KWin script + effect for KDE Plasma 6 (Wayland). Your windows slide down
off the screen, revealing the desktop, and slide back into place in their original
order when you swipe up again — like a quick "peek at desktop" on your touchpad.

![Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-1d99f3?logo=kde&logoColor=white)
![Wayland](https://img.shields.io/badge/session-Wayland-informational)
![License: GPL-2.0-or-later](https://img.shields.io/badge/license-GPL--2.0--or--later-blue)

[Türkçe açıklama aşağıda ↓](#türkçe)

---

## What it does

| Gesture | Result |
| --- | --- |
| 4 fingers **down** | All windows slide down off the screen → the desktop is shown |
| 4 fingers **down** (Window View open) | Closes Window View; windows return to where they were |
| 4 fingers **up** (desktop shown) | Windows slide back up into their old positions and stacking order |
| 4 fingers **up** (normal) | Opens **Window View** (Present Windows) to see all your windows |
| 4 fingers **left** / **right** | Shows a live preview strip of your windows; keep swiping to move up to 4 windows ahead (left = next, right = previous). **Lift your fingers to switch** to the selected window, or swipe back to the start to cancel |

- **Instant:** the action fires as soon as you start swiping — you don't have to
  swipe far or lift your fingers.
- **Fast:** a short 200 ms slide animation (respects Plasma's global animation speed).
- Works with <kbd>Meta</kbd>+<kbd>D</kbd> too: show the desktop with the keyboard,
  bring the windows back with a swipe (or vice versa).

**Note:** KWin also hard-codes 4-finger left/right swipes for switching virtual
desktops. If you have more than one virtual desktop in a row, both will happen, so the
window-switching gesture works best with a single desktop (one row, one column).

## ⚠️ One trade-off: Overview is turned off

Plasma's built-in **Overview** effect hard-codes the 4-finger up/down swipes
(up = Overview, down = Grid View) and there is no setting to change them. KWin fires
*every* gesture that matches a swipe, so if Overview stayed on, swiping down would
show the desktop **and** open Grid View at the same time.

So the installer disables the Overview effect. That means:

- 4-finger up opens **Window View** instead of Overview (it also shows all windows
  and you can type to search, but there is no virtual-desktop strip).
- The <kbd>Meta</kbd>+<kbd>W</kbd> (Overview) and <kbd>Meta</kbd>+<kbd>G</kbd> (Grid View)
  shortcuts stop working. Window View is still on <kbd>Ctrl</kbd>+<kbd>F9</kbd>.

`uninstall.sh` turns Overview back on.

## Requirements

- KDE Plasma **6** (tested on Plasma 6.8)
- A **Wayland** session (KWin touchpad gestures do not work on X11)
- A touchpad that supports 4-finger gestures

## Install

```bash
git clone https://github.com/metoi01/kwin-four-finger-desktop.git
cd kwin-four-finger-desktop
./install.sh
```

No root needed — everything goes into `~/.local/share/kwin` and `~/.config/kwinrc`
(a backup of `kwinrc` is made first). It takes effect immediately, no logout required.
Re-running `./install.sh` (e.g. after editing a setting or `git pull`) applies the
changes immediately too, again without logging out.

After installing you will find both parts in **System Settings**:

- *Window Management → KWin Scripts →* **Four Finger Desktop**
- *Window Management → Desktop Effects → Show Desktop Animation →* **Slide Down Desktop**
- *Window Management → Desktop Effects → Window Management →* **Four Finger Switcher**

## Uninstall

```bash
./uninstall.sh
```

Removes all three packages and restores Plasma's defaults (Overview + Window Aperture).

## Customize

| What | Where | Default |
| --- | --- | --- |
| How far you have to swipe | `threshold` in [`fourfingerdesktop/contents/ui/main.qml`](fourfingerdesktop/contents/ui/main.qml) | `0.1` (≈ 20 touchpad units; `1.0` = 200) |
| Swap left/right window switching | `invertHorizontal` in [`fourfingerswitcher/contents/ui/Switcher.qml`](fourfingerswitcher/contents/ui/Switcher.qml) | `false` (left = next window) |
| Animation length | `animationTime(200)` in [`slidedowndesktop/contents/code/main.js`](slidedowndesktop/contents/code/main.js) | 200 ms |
| What 4-finger up opens | `arguments: ["Expose"]` in `main.qml` | `Expose` (Window View, current desktop). `ExposeAll` = all desktops |

Run `./install.sh` again after editing to apply your changes.

## How it works

The project is three independent KWin packages:

1. **`fourfingerdesktop`** — a declarative (QML) KWin script. It registers two
   `SwipeGestureHandler`s (4 fingers, up and down) and talks to KWin over D-Bus:
   `org.kde.KWin.showDesktop(true/false)` to show/hide the desktop, the
   `showingDesktop` property to decide what "up" should do, and
   `org.kde.kglobalaccel` to open Window View.
   KWin only reports a swipe as *activated* after the full 200-unit distance, so the
   script watches the swipe's `progress` and fires as soon as it crosses the threshold.
2. **`slidedowndesktop`** — a JavaScript KWin effect in the *Show Desktop Animation*
   category (adapted from KWin's *Window Aperture*). When KWin enters "show desktop"
   it translates every hidden window down past the bottom of its screen, and plays the
   same animation backwards when the desktop is hidden again.
3. **`fourfingerswitcher`** — a declarative (QML) KWin effect with a fullscreen overlay.
   Its left/right `SwipeGestureHandler`s drive the preview strip; the selection steps
   (at 10 / 40 / 70 / 97 % of the swipe) follow your fingers and the window is switched
   when you lift them.

Because it only uses KWin's public scripting/effect APIs, it touches no system files
and survives system updates (including immutable distros like Fedora Kinoite / Bazzite).

## Troubleshooting

- **Nothing happens:** make sure you are on Wayland (`echo $XDG_SESSION_TYPE`) and that
  the script is enabled in *System Settings → KWin Scripts*.
- **Sometimes it doesn't trigger:** your touchpad may be registering 3 fingers instead of 4.
  Check with `sudo libinput debug-events` and look for `GESTURE_SWIPE_BEGIN ... 4`.
- **Logs:** `journalctl --user -b | grep -iE "fourfinger|slidedown"`

---

## Türkçe

**Dört parmakla aşağı kaydır, masaüstün görünsün. Yukarı kaydır, pencerelerin geri gelsin.**

KDE Plasma 6 (Wayland) için küçük bir KWin betiği ve efekti.

| Hareket | Sonuç |
| --- | --- |
| 4 parmak **aşağı** | Tüm pencereler ekranın altına kayar, masaüstü görünür |
| 4 parmak **aşağı** (Pencere Görünümü açıkken) | Pencere Görünümü kapanır, pencereler eski yerlerine döner |
| 4 parmak **yukarı** (masaüstü açıkken) | Pencereler eski yerlerine, eski sıralarıyla geri döner |
| 4 parmak **yukarı** (normalde) | **Pencere Görünümü** açılır, tüm pencereleri görürsün |
| 4 parmak **sola** / **sağa** | Pencerelerin canlı önizleme şeridi açılır; kaydırmaya devam ettikçe en fazla 4 pencere ileri gidersin (sola = sonraki, sağa = önceki). **Parmaklarını kaldırınca** seçili pencereye geçilir; başa dönersen iptal olur |

- Hareketi algıladığı anda çalışır; uzun kaydırmana veya parmağını kaldırmana gerek yok.
- Animasyon kısa (200 ms).
- KWin 4 parmak sola/sağa hareketini sanal masaüstü geçişi için de kendi koduna sabit yazmıştır; bir satırda birden fazla sanal masaüstün varsa ikisi birden olur, bu yüzden tek masaüstüyle en iyi çalışır.

**Not:** Plasma'nın **Genel Bakış (Overview)** efekti 4 parmak yukarı/aşağı hareketlerini
kendi koduna sabit yazmış ve değiştirme ayarı yok. Bu yüzden kurulum Genel Bakış'ı kapatır;
4 parmak yukarı onun yerine Pencere Görünümü'nü açar. <kbd>Meta</kbd>+<kbd>W</kbd> ve
<kbd>Meta</kbd>+<kbd>G</kbd> kısayolları çalışmaz, Pencere Görünümü <kbd>Ctrl</kbd>+<kbd>F9</kbd>
ile açılır. `uninstall.sh` her şeyi eski haline getirir.

**Kurulum:**

```bash
git clone https://github.com/metoi01/kwin-four-finger-desktop.git
cd kwin-four-finger-desktop
./install.sh
```

**Kaldırma:** `./uninstall.sh`

Root yetkisi gerekmez; her şey ev klasörüne kurulur ve hemen çalışır. Ayarlar (kaydırma
mesafesi, animasyon süresi) için yukarıdaki *Customize* tablosuna bak.

---

## License

[GPL-2.0-or-later](LICENSE), the same license as KWin.
The slide animation is adapted from KWin's *Window Aperture* effect by Thomas Lübking.
