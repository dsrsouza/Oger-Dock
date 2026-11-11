# Oger Dock architecture

Oger Dock is a Plasma applet that combines **QML/JavaScript** presentation and state management with **native C++** integration for KDE services. The release ships its complete source tree and compiles the native module on the user's system.

| Area | Purpose |
|---|---|
| `contents/ui/` | QML interface, application menus, popups, settings, player |
| `contents/code/` | JavaScript behavior: dock items, navigation, wheel input, folder visuals |
| `contents/config/` | Plasma configuration screens and persisted keys |
| `src/` | Native C++ integration with KDE and Qt |
| `scripts-user/` | Dependency checks, source build, packaging and installation |
| `tests-dev/` | Focused regression tests and maintenance checks |
| `po/` | Translation catalogs |
| `metadata.json` | KDE Plasma applet identity, version and translations |

## Compatibility invariants

- Public application identity: **Oger Dock** 1.0.0.
- Internal Plasma applet ID: `org.kde.plasma.punchi-dock-remastered` retained for updates.
- Existing settings and persistent item formats should not be changed without migration.
- R63.7 scroll regression must not return: wheel navigation may not activate or promote tray-only apps inadvertently.
- SNI/DBusMenu capabilities depend on third-party applications and KDE TaskManager visibility.

The original Punchi Dock Remastered provenance is documented in [NOTICE](../NOTICE). For development practices, see [CONTRIBUTING](../CONTRIBUTING.md).
