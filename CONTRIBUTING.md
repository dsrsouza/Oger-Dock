# Contributing to Oger Dock

Thank you for helping improve Oger Dock. This repository maintains a native KDE Plasma 6 dock, based on the GPL-3.0-or-later licensed [Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered).

## Before reporting a bug

Check [Issues](https://github.com/dsrsouza/Oger-Dock/issues) and [Discussions](https://github.com/dsrsouza/Oger-Dock/discussions). Please include:

- Distribution, KDE Plasma, Qt, and KDE Frameworks versions.
- Wayland or X11 session.
- The Oger Dock version and install method.
- Exact reproduction steps, expected outcome, and actual outcome.
- Logs and screenshots only after removing private information.

## Contributions and compatibility

Keep patches focused and test changes on KDE Plasma 6. Avoid changing the internal applet ID (`org.kde.plasma.punchi-dock-remastered`), QML imports, translation domains, and stored configuration without a migration plan. Preserve regression-protected R63.7 mouse-wheel/tray behavior and existing KDE preferences.

Run the applicable tests and native build before presenting a change as validated. Do not describe an automated check as a successful visual or compatibility test.

## Credit and AI-assisted development

Preserve the source-file copyright notices, `NOTICE` and `LICENSE`. If AI tools assisted a contribution, verify the result, note relevant changes, and preserve third-party attribution and GPL obligations.
