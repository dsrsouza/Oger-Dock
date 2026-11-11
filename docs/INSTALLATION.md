# Installing Oger Dock 1.0.0

For a **native build**, obtain the complete release source (not only the public introductory README). Build on the same KDE Plasma 6 installation on which the applet will run, so its native modules match the system Qt/KDE libraries.

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

The package names vary by distribution and version. Start with the package-manager instructions in the [Brazilian Portuguese dependency guide](INSTALACAO.pt_BR.md#2-prepare-as-depend%C3%AAncias): it covers **openSUSE Tumbleweed (`zypper`)**, **Fedora (`dnf`)**, and **Debian/Ubuntu (`apt`)**. The example lists are initial guidance adapted to a comparable Plasma 6 build system; use `bash scripts-user/setup.sh --check-deps` to verify the final Oger Dock source requirements before building.

Do not attempt to turn a Plasma 5 system into a supported environment merely by installing development package names. Native compilation and runtime versions must match.

## Troubleshooting

- Re-run the dependency check and inspect missing Qt/KF6/Plasma development packages.
- After upgrading Plasma, rebuild with the new host libraries and re-login.
- For applet load or tray issues, report your Linux distribution, Plasma and Qt versions, Wayland/X11, and a reproducible procedure at [GitHub Issues](https://github.com/dsrsouza/Oger-Dock/issues).

For questions, use [GitHub Discussions](https://github.com/dsrsouza/Oger-Dock/discussions) once enabled.