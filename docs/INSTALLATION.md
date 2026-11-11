# Installing Oger Dock 1.0.0

The **complete 1.0.0 source tree is published on the `main` branch**. Release installer archives are also available under [Releases](https://github.com/dsrsouza/Oger-Dock/releases). Build on the same KDE Plasma 6 installation on which the applet will run, so its native modules match the system Qt/KDE libraries.

The main functional development environment is **openSUSE Tumbleweed with Plasma 6.8.2 and Wayland**. Fedora and Debian/Ubuntu are intended targets, not yet fully certified.

## Quick start

```bash
git clone https://github.com/dsrsouza/Oger-Dock.git
cd Oger-Dock
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

For a full installer archive, extract it and run the three `scripts-user/setup.sh` commands in its directory; cloning is unnecessary. Run builds as your normal desktop user, not with `sudo`.

After installation, use **Add Widgets** in KDE Plasma to add Oger Dock. Log out and back in if an already-loaded native module needs refreshing. Preserve the existing applet settings when upgrading.

## Distribution dependencies

The project source requires **CMake 3.22+, C++20, Qt6 6.6+, KF6 6.0+, Plasma 6.0+, PlasmaQuick, Activities, ActivitiesStats, LibKWorkspace, ECM, Gettext, PipeWire 0.3 development headers, pkg-config and `qsb` (Qt Shader Baker)**. The lists below are mapped from `CMakeLists.txt` and `src/CMakeLists.txt` in the Oger Dock 1.0.0 installer.

**Choose the command for your distribution only.** Some package names may change across versions; don't mix repositories from unrelated distributions or forcibly downgrade Qt/KDE packages.

### openSUSE Tumbleweed / Leap (compatible Plasma 6)

```bash
sudo zypper refresh
sudo zypper install \
  binutils cmake make gcc-c++ kf6-extra-cmake-modules gettext-tools git pkgconf-pkg-config \
  qt6-base-devel qt6-declarative-devel qt6-shadertools \
  kf6-kconfig-devel kf6-kcoreaddons-devel kf6-kglobalaccel-devel \
  kf6-ki18n-devel kf6-kjobwidgets-devel kf6-kio-devel \
  kf6-kpackage-devel kf6-kservice-devel kf6-kwindowsystem-devel \
  libplasma6-devel plasma6-workspace-devel \
  plasma6-activities-devel plasma6-activities-stats-devel \
  pipewire-devel unzip zip
```

Check any reported missing package using `zypper search <package-name>`. In the current Oger Dock source, the openSUSE `--check-deps` pre-check covers only some mandatory development packages, so follow the complete list above.

### Fedora KDE

```bash
sudo dnf install \
  binutils cmake make gcc-c++ extra-cmake-modules gettext git pkgconf-pkg-config \
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtshadertools \
  kf6-kconfig-devel kf6-kcoreaddons-devel kf6-kglobalaccel-devel \
  kf6-ki18n-devel kf6-kjobwidgets-devel kf6-kio-devel \
  kf6-kpackage-devel kf6-kservice-devel kf6-kwindowsystem-devel \
  libplasma-devel plasma-workspace-devel \
  plasma-activities-devel plasma-activities-stats-devel \
  pipewire-devel unzip zip
```

### Debian, Ubuntu, Kubuntu and KDE neon with Plasma 6

```bash
sudo apt update
sudo apt install \
  binutils build-essential cmake extra-cmake-modules gettext git pkg-config \
  qt6-base-dev qt6-base-dev-tools qt6-declarative-dev \
  qt6-declarative-dev-tools qt6-shader-baker \
  libkf6config-dev libkf6coreaddons-dev libkf6globalaccel-dev \
  libkf6i18n-dev libkf6jobwidgets-dev libkf6kio-dev \
  libkf6package-dev libkf6service-dev libkf6windowsystem-dev \
  libplasma-dev plasma-workspace-dev \
  libplasmaactivities-dev libplasmaactivitiesstats-dev \
  libpipewire-0.3-dev unzip zip
```

These instructions require a distribution version whose repositories actually provide Plasma 6 and the matching development libraries. A Plasma 5 environment is not sufficient.

### Arch Linux / Manjaro with Plasma 6

```bash
sudo pacman -Syu --needed \
  base-devel binutils cmake extra-cmake-modules gettext git pkgconf \
  qt6-base qt6-declarative qt6-shadertools \
  kconfig kcoreaddons kglobalaccel ki18n kjobwidgets kio \
  kpackage kservice kwindowsystem \
  libplasma plasma-workspace plasma-activities plasma-activities-stats \
  pipewire unzip zip
```

The package list targets the official Arch package names. On Manjaro, availability depends on the distribution branch and package versions.

### Validate dependencies and build

From the **complete extracted release folder** (or a checkout **only after source publication**):

```bash
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

**Note:** `--check-deps` tests a **subset** of the full CMake dependency graph, not every package above; a green pre-check does not replace a successful CMake configure/build. The final release has not been end-to-end validated on every distro.

## Troubleshooting

- Re-run the dependency check and inspect missing Qt/KF6/Plasma development packages.
- After upgrading Plasma, rebuild with the new host libraries and re-login.
- For applet load or tray issues, report your Linux distribution, Plasma and Qt versions, Wayland/X11, and a reproducible procedure at [GitHub Issues](https://github.com/dsrsouza/Oger-Dock/issues).

For questions, use [GitHub Discussions](https://github.com/dsrsouza/Oger-Dock/discussions) once enabled.