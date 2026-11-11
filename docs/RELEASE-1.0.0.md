# Oger Dock 1.0.0

**Initial public source-based release**, built on the R63.7 baseline for KDE Plasma 6.

## Highlights

- Dock for pinned applications, running windows and scroll-based switching.
- Animated fan folders, custom colors and application picker.
- Normal/Reduced application menu and KDE session actions.
- MPRIS mini player, Trash integration and configurable appearance.
- Native SNI/DBusMenu integration when exported by third-party apps.
- Approved R63.7 fix preventing MEGA tray-only activation during wheel switching.

## Installation

A ZIP/TAR.GZ release contains source and build scripts, **not** a universal prebuilt `.plasmoid`.

```bash
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

Run from the extracted project root, as your regular desktop user. KDE Plasma may require logout/login to reload the native module. Preserve your existing settings.

## Testing status

Targeted regression tests: 11/11 passed. Bash syntax checks: 13/13 passed. The R63.7 MEGA/scroll fix was confirmed in the maintainer's openSUSE Tumbleweed / Plasma 6.8.2 / Wayland environment. **Native compilation of this final archive and end-to-end compatibility across all distributions have not yet been confirmed.**

## License and contributors

- **Diego Souza.R**
- **Punchisoft**

Based on [Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered), by PunchiSoft. Licensed under GPL-3.0-or-later; preserve applicable [copyright notices](../NOTICE).
