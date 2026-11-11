# Oger Dock 1.0.0 — Guia da primeira versão pública

**Data:** 2026-11-10. **Base técnica:** R63.7. **Alvo principal:** KDE Plasma 6.8.2, Wayland, openSUSE Tumbleweed.

## Metadados oficiais

- Nome público: **Oger Dock**
- Versão: **1.0.0**
- Autores: **Diego Souza.R** e **Punchisoft** (entradas separadas)
- GitHub: https://github.com/dsrsouza/Oger-Dock
- Suporte: https://www.reddit.com/r/OgerDock/
- Licença: GPL-3.0-or-later

## Por que alguns identificadores continuam com “punchi”?

O `KPlugin.Id` **continua `org.kde.plasma.punchi-dock-remastered`** e o URI do módulo nativo permanece `org.punchi.dock`. Este compromisso é intencional: renomear essas identidades sem migração completa quebra a descoberta do plugin, as configurações existentes, atalhos, catálogos e dados persistidos. Portanto, o usuário verá **Oger Dock**, mas o Plasma instalará uma atualização do mesmo plasmoide, não um segundo widget.

Nomes técnicos de classes C++, QML, schemas, scripts e estruturas de armazenamento legados não são a marca exibida e foram mantidos.

## Instalação

Extraia o ZIP/TAR.GZ, abra um terminal na pasta `Oger-Dock-1.0.0-Fonte` e execute:

```bash
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

Reinicie a sessão Plasma após instalar. As preferências anteriores devem continuar disponíveis; não apague a pasta de dados nem os itens antigos durante a atualização.

O instalador gera um `.plasmoid` compilado localmente em `dist/` com prefixo `oger-dock-1.0.0-...` (o nome depende da distribuição). O ZIP do projeto é um **kit de instalação a partir do código**, não um arquivo `.plasmoid` pré-compilado.

## Teste de aceite

1. Confira em **Sobre**: nome Oger Dock, versão 1.0.0, autores em duas linhas e links corretos.
2. Abra a página **Itens** e confirme ícones, pastas, cores, reorganização e Aplicar/Cancelar sem perder a configuração pré-existente.
3. Abra **Pastas** e confirme os nomes e cores reais das pastas do usuário.
4. Alterne rapidamente entre todas as categorias de configuração.
5. Com MEGA exclusivamente na tray, use scroll em Firefox/Dolphin: o popup não pode ser ativado pelo scroll; valide limites da rolagem.
6. Teste o mini-player, leque, menu e aplicativos da tray sem duplicação.

## Limitações conhecidas

A geometria de popups de terceiros em Wayland e a ativação SNI do MEGA dependem do próprio aplicativo e do KDE. A promoção temporária à dock não garante reposicionamento dos popups externos. Se a compatibilidade do sistema mudar, a versão 1.0.0 pode exigir ajustes adicionais.

## Homologação e compilação

O código da R63.7 foi testado pelo usuário para a correção de scroll; o lançamento 1.0.0 deve passar por uma compilação e aceite completos em ambiente Plasma real antes de ser considerado homologado. O ambiente de preparação não possui ECM/KF6 suficientes para compilação nativa.

## Documentação de IA e pacote limpo

A edição final contém `README.en.md`, `INSTALACAO.md`, `AGENTS.md` e as referências `docs/IA-HISTORICO-CORRECOES.md`, `docs/IA-MAPA-TECNICO.md` e `docs/IA-TESTES-E-SEGURANCA.md`. Elas registram especialmente os erros das revisões R62.5, R63.2, R63.5 e R63.6, para que uma futura IA não repita soluções que falharam. A versão distribui catálogos ingleses (`po/en.po`) além dos catálogos de português, espanhol e alemão.

O arquivo opcional `Oger-Dock-1.0.0-Historico-Desenvolvimento.zip` guarda documentos e testes legados, que não precisam acompanhar o instalador principal. O pacote do usuário mantém 11 testes atuais curados, sem scripts A/B de monitoramento e sem a integração KWin do MEGA, rejeitada em testes reais.
