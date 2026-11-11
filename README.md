# Oger Dock

<p align="center">
  <strong>A customizable dock for KDE Plasma 6</strong>
</p>

<p align="center">
  <img alt="Version 1.0.0" src="https://img.shields.io/badge/version-1.0.0-3b82f6">
  <img alt="KDE Plasma 6" src="https://img.shields.io/badge/KDE_Plasma-6-1d99f3?logo=kde">
  <img alt="Linux" src="https://img.shields.io/badge/platform-Linux-555555?logo=linux">
  <img alt="GPL-3.0-or-later" src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue">
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.pt_BR.md">Português (Brasil)</a>
</p>

Oger Dock brings application launchers, running windows, customizable folders, media controls and everyday desktop tools into a single, fluid dock built for **KDE Plasma 6**. It is designed for users who want a personalized desktop without losing integration with KDE applications and services.

The **1.0.0** release is based on the project's validated R63.7 behavior. Development and initial functional testing have focused on **openSUSE Tumbleweed, KDE Plasma 6.8.2 and Wayland**. This does not imply certification on all Plasma 6 installations.

 > [!IMPORTANT]
> This repository currently contains the public documentation. The complete source installer will be published under [Releases](https://github.com/dsrsouza/Oger-Dock/releases); until then, the checkout alone cannot be compiled.

[Features](#features) · [Screenshots](#screenshots) · [Installation](#installation) · [Compatibility](#compatibility) · [Testing](#testing-and-quality) · [Support](#support-and-community) · [License](#license)

## Features

### Applications and windows

- **Custom launchers and pinned apps:** keep commonly used applications at hand and organize dock items according to your workflow.
- **Window switching with the mouse wheel:** cycle sequentially through eligible open applications, respecting scroll direction and list boundaries.
- **Window-aware indicators:** distinguish running applications and their active state with configurable visual cues.
- **Reordering:** unlock the dock when you want to rearrange launchers and other items.

### System tray integration

- **StatusNotifierItem (SNI) integration:** reuse existing compatible tray applications and their native menus when those menus are provided by the application.
- **Existing-instance behavior:** restore a recognized running app without starting unnecessary duplicate processes.
- **Autostart protection:** applications that launch automatically with the desktop are not automatically added as dock items just because they publish an SNI.
- **Protected scrolling:** scrolling across dock applications does not inadvertently promote tray-only programs such as MEGAsync to dock entries (R63.7 validation).
- **Return to tray:** supported temporary entries can be removed from the dock while their application continues to run.

Some tray behaviors depend on what KDE's task manager and the third-party application's SNI actually expose.

### Folders and application organization

- **Fan-style folders:** open organized collections in a fluid fan presentation.
- **Personalized folders:** choose folder names and individual colors, or inherit category/theme defaults.
- **Application picker:** find installed KDE applications by search and category, with multi-selection when building collections.
- **Drag and drop:** organize applications and folders with direct manipulation.

### Application menu

- **Normal and Reduced layouts:** choose the menu size that fits your desktop.
- **Application search and categories:** quickly locate installed programs.
- **Session controls:** access supported KDE shutdown, restart and logout actions.

### Media and desktop utilities

- **Compact MPRIS player:** artwork and previous/play-pause/next controls for compatible active media sources.
- **Expandable track information:** track details appear without enlarging or shifting the dock's fixed player controls.
- **Trash integration:** open Trash in Dolphin, empty it and confirm destructive actions.
- **Visual appearance:** Plasma-friendly theme integration, folder colors, indicators and animations.
- **Dock placement:** bottom, left or right side of the screen; top placement is intentionally not offered.

## Screenshots

Real Oger Dock screenshots will be added to `docs/images/` before the visual gallery is published. Planned captures include the horizontal dock, side dock, Normal/Reduced menu, fan folders, compact player and Settings. Images from other dock projects are not Oger Dock screenshots.

See the [screenshot checklist](docs/SCREENSHOTS.md) for recommended captures and filenames.

## Installation

### Download a release

Once the first public release is uploaded, find its packages under [GitHub Releases](https://github.com/dsrsouza/Oger-Dock/releases). Extract the installer archive and use the included `scripts-user/setup.sh` script from the project root.

### Build and install from source

After the complete source tree is published here, open a terminal:

```bash
git clone https://github.com/dsrsouza/Oger-Dock.git
cd Oger-Dock
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

Use the normal desktop account, not root, for the build/install script. After installation, add **Oger Dock** from KDE Plasma's **Add Widgets** interface. A logout/login may be needed to reload an updated native module. Do not delete your existing dock settings when upgrading.

For distribution-specific dependency commands and troubleshooting, read the [installation guide](docs/INSTALLATION.md) or [guia de instalação em português](docs/INSTALACAO.pt_BR.md).

## Compatibility

| Environment | Project status |
|---|---|
| openSUSE Tumbleweed + KDE Plasma 6.8.2 + Wayland | Main development and user-testing environment |
| Other KDE Plasma 6.8+ environments | Intended targets; verify dependencies and native compatibility |
| Fedora with KDE Plasma 6 | Installation guide provided; end-to-end validation pending |
| Debian/Ubuntu with KDE Plasma 6 | Installation guide provided; end-to-end validation pending |
| Non-KDE desktops | Not supported |

The native components depend on the Qt and KDE libraries of the host system. A Plasma or Qt upgrade may require rebuilding and reinstalling the applet.

**Existing installations:** the internal technical applet identifier `org.kde.plasma.punchi-dock-remastered` is retained for settings and upgrade continuity. The public project name is **Oger Dock**.

## Testing and quality

The 1.0.0 preparation included automated regression and installation-script checks. Prior checks reported **11/11 targeted tests** and **13/13 script checks** passing. These checks do not replace native compilation, visual review and full end-to-end testing in every target distribution.

One specifically user-confirmed behavior is the R63.7 correction that prevents scrolling from inadvertently activating/promoting the MEGA tray application. Other features should be validated against the actual installed release.

When reporting a problem, include the distribution, Plasma version, Qt version, session type (Wayland/X11), steps to reproduce and relevant logs.

## Support and community

- **Questions and discussions:** [GitHub Discussions](https://github.com/dsrsouza/Oger-Dock/discussions) (repository Discussions must be enabled).
- **Bugs and feature requests:** [GitHub Issues](https://github.com/dsrsouza/Oger-Dock/issues).
- **Community:** [r/OgerDock on Reddit](https://www.reddit.com/r/OgerDock/).

Contributions to bug reports, documentation, translations and testing are welcome. Please keep technical reports reproducible and avoid posting personal information in logs.

## Project structure

The source layout is expected to include the following project areas when the full source is published:

```text
contents/       QML interface, JavaScript, icons and configuration
src/            native integration (C++)
scripts-user/   installation, build and dependency checks
tests-dev/      regression tests and development validations
metadata.json   KDE Plasma applet metadata
AGENTS.md       AI-agent development guidance
```

The installer and archive layout should be reviewed against the exact final release before publishing these paths as a definitive inventory.

### AI-assisted development

AI-based tools supported investigation, implementation proposals, refactoring, testing and documentation during development. Technical review, functional decisions and final release validation remain the responsibility of the project maintainers. Development instructions and historical notes are kept with the source/release documentation where available.

## Credits

**Diego Souza.R**  
**Punchisoft**

## License

Oger Dock is distributed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**. The full license text and all applicable third-party copyright/attribution notices must accompany the published source and distribution packages. See the [GPL-3.0 license](https://www.gnu.org/licenses/gpl-3.0.html).