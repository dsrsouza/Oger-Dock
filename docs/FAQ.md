# Frequently asked questions / Perguntas frequentes

## Is Oger Dock a universal `.plasmoid` download?

No. The first source-based installer builds a native `.plasmoid` locally against the Qt/KDE Plasma libraries installed on your computer. A precompiled universal package has not been validated.

## Where can I find support?

Open [GitHub Discussions](https://github.com/dsrsouza/Oger-Dock/discussions) for help and ideas (Discussions must be enabled). Report reproducible bugs under [Issues](https://github.com/dsrsouza/Oger-Dock/issues).

## Can I update without losing my pinned applications?

The 1.0.0 package keeps the legacy internal Plasma applet ID to preserve existing settings. Do not delete the old configuration or uninstall solely to update. Back up Plasma settings before major changes.

## Why doesn't an application that started with Linux automatically appear in the dock?

Apps that publish a System Tray icon during autostart are intentionally not added to the dock just for existing. A user-triggered interaction with a recognized window may enable a temporary dock entry; actual behavior depends on SNI and KDE window reporting.

## Why are other Linux distributions not marked as tested?

The confirmed user environment is openSUSE Tumbleweed with KDE Plasma 6.8.2/Wayland. Source compatibility and successful KDE runtime behavior depend on library versions and full local validation.

## What about translations?

The 1.0.0 source installer includes catalog files for English, Brazilian Portuguese, Spanish and German. Translation completeness does not imply each catalog received a native-speaker review.

## Perguntas rápidas

- **Como instalar?** Consulte [Instalação](INSTALACAO.pt_BR.md).
- **Como relatar um bug?** Use [Issues](https://github.com/dsrsouza/Oger-Dock/issues) e informe distribuição, Plasma/Qt, sessão e passos para reproduzir.
- **Preciso apagar a versão antiga?** Não. Preserve configurações e itens fixados.
- **Como criar a release?** Consulte [Publicação](PUBLICACAO.pt_BR.md).
