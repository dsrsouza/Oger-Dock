# Oger Dock 1.0.0 — informações de lançamento

**Base técnica:** revisão R63.7. **Alvo principal:** openSUSE Tumbleweed, KDE Plasma 6.8.2, Wayland.

## Destaques

- Nome público Oger Dock, versão 1.0.0, créditos Diego Souza.R e Punchisoft.
- Dock KDE Plasma 6 com janelas, lançadores e indicadores.
- Pastas com leque animado, cores individuais e organização de itens.
- Menus Normal e Reduzido, mini player MPRIS, lixeira e posições inferior/laterais.
- Integração com apps da tray e menus SNI/DBusMenu quando disponibilizados.
- Correção de alternância por rolagem que impede ativar indevidamente o MEGA exclusivo da tray — confirmada em teste real na R63.7.
- Estrutura de distribuição baseada em código-fonte, compilada no sistema do usuário.

## Situação de testes

A correção MEGA/scroll foi confirmada no ambiente do mantenedor. Testes automatizados e checagens de scripts foram usados na preparação da release, mas **não** constituem validação completa da instalação, compilação ou interface do pacote em todas as distribuições. Cada ambiente precisa de validação própria.

## Instalação

O instalador ZIP/TAR.GZ contém fontes e scripts, não um `.plasmoid` universal pré-compilado. Extraia o pacote completo, abra o terminal na pasta extraída e execute:

```bash
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

Saia e entre novamente na sessão KDE Plasma se necessário. Atualizações devem preservar as preferências anteriores.

## Links

- [Guia em português](INSTALACAO.pt_BR.md)
- [Installation guide](INSTALLATION.md)
- [Problemas](https://github.com/dsrsouza/Oger-Dock/issues)
- [Discussões](https://github.com/dsrsouza/Oger-Dock/discussions)

**Créditos:** Diego Souza.R; Punchisoft. Baseado em Punchi Dock Remastered, de PunchiSoft. Licença GPL-3.0-or-later, com avisos originais preservados.
