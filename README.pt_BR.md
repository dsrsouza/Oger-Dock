<p align="center"><img src="Images/oger-logo.png" width="152" alt="Logotipo oficial Oger Dock com mascote ogro"></p>
<h1 align="center">Oger Dock</h1>
<p align="center"><strong>Seu KDE Plasma, do seu jeito.</strong></p>
<p align="center">
  <a href="https://github.com/dsrsouza/Oger-Dock/releases"><img src="https://img.shields.io/badge/version-1.0.0-f59e54" alt="Version 1.0.0"></a>
  <img src="https://img.shields.io/badge/KDE_Plasma-6-1d99f3?logo=kde" alt="KDE Plasma 6">
  <img src="https://img.shields.io/badge/Linux-Wayland-informational?logo=linux" alt="Linux Wayland">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="GPL-3.0-or-later"></a>
</p>

<p align="center"><strong>Lançadores · Janelas abertas · Pastas em leque · Mini player MPRIS · Integração com KDE</strong></p>
<p align="center"><a href="README.md">English</a> | <a href="README.pt_BR.md">Português (Brasil)</a></p>

O **Oger Dock** é uma dock fluida e personalizável para o **KDE Plasma 6**, que reúne aplicativos fixados, alternância de janelas, pastas animadas, player multimídia e ferramentas da área de trabalho. A versão **1.0.0** preserva a base funcional R63.7, desenvolvida e testada principalmente no **openSUSE Tumbleweed, KDE Plasma 6.8.2 e Wayland**.

> [!IMPORTANT]
> O código-fonte completo do Oger Dock 1.0.0 **já está disponível neste repositório**. Os instaladores ZIP/TAR.GZ estão disponíveis em [Releases](https://github.com/dsrsouza/Oger-Dock/releases). Esses pacotes compilam localmente; não são binários `.plasmoid` universais.

[Recursos](#recursos) · [Galeria](#galeria) · [Instalação](#instalação) · [Compatibilidade](#compatibilidade) · [Testes](#testes-e-qualidade) · [Comunidade](#comunidade-e-suporte) · [Licença](#licença)

<p align="center"><img src="Images/oger-brand-cover.svg" width="920" alt="Identidade visual oficial Oger Dock em verde-oliva, cobre e grafite"></p>

## Recursos

### Aplicativos e janelas
- **Lançadores e favoritos:** fixe aplicativos e organize os atalhos na dock.
- **Alternância pela roda do mouse:** percorra sequencialmente os aplicativos elegíveis, respeitando a direção e os limites da lista.
- **Indicadores de execução:** acompanhe visualmente quais aplicativos estão abertos e ativos.
- **Reorganização:** destrave a dock para mover ícones, pastas e outros itens.

### Pastas e coleções
- **Pastas em leque:** abra coleções com animação fluida e organização visual.
- **Cores individuais:** personalize o nome e a cor de cada pasta, mantendo padrões por categoria/tema.
- **Seletor de aplicativos:** pesquise por nome ou categoria e adicione vários programas às coleções.

### OgerMenu
- **Modos Normal e Reduzido:** duas apresentações adequadas a diferentes espaços de trabalho.
- **Pesquisa e categorias:** encontre rapidamente aplicativos instalados.
- **Ações de sessão KDE:** desligar, reiniciar e encerrar a sessão.

### Multimídia e utilitários
- **Mini player MPRIS:** capa e botões anterior, reproduzir/pausar e próximo para players compatíveis.
- **Informações expansíveis:** título e artista aparecem sem deslocar os controles fixos.
- **Lixeira:** abrir no Dolphin, esvaziar com confirmação e acessar ações comuns.

### Aparência, bandeja e interação
- **Posições:** inferior (padrão), esquerda ou direita; a posição superior não é oferecida.
- **Estilo integrado ao KDE:** aparência configurável, animações e indicadores visuais.
- **SNI/DBusMenu:** aplicativos compatíveis podem apresentar menus nativos e reutilizar processos abertos.
- **Respeito ao autostart:** programas da bandeja não ganham ícone na dock apenas por iniciar com o sistema.
- **Correção R63.7:** o scroll não ativa ou promove indevidamente programas exclusivos da bandeja, como o MEGAsync.

A integração depende das informações efetivamente fornecidas pelo aplicativo e pelo KDE TaskManager. Nem todo popup de terceiros pode ser controlado pela dock.

## Galeria

### Demonstrações dos recursos

As oito imagens de apresentação já foram preparadas com uma área de trabalho fictícia e nomes de arquivos genéricos. Elas serão exibidas automaticamente aqui após a importação do ZIP verificado. As capturas originais que mostravam arquivos pessoais **não serão publicadas**.

| Recurso | O que a demonstração apresenta |
|---|---|
| **OgerMenu** | Busca de aplicativos, categorias, grade de ícones e ações de sessão do KDE |
| **Pastas em leque** | Grupos de atalhos abertos com animação em leque |
| **Integração com Dolphin** | Abertura de diretórios pelo gerenciador de arquivos do KDE |
| **Menus nativos da bandeja** | Ações SNI/DBusMenu oferecidas por aplicativos compatíveis |
| **Popup da lixeira** | Lista de arquivos, esvaziamento com confirmação e abertura no Dolphin |
| **Mini player integrado** | Controles MPRIS, capa e informações da música |
| **Menu de contexto da dock** | Destravar, inserir separadores, tema e configurações |
| **Painel de configurações** | Organizar ícones, pastas, menus, áudio, janelas e atalhos |

[Como publicar a galeria](docs/GALERIA-IMPORTACAO.pt_BR.md) · [Orientações para capturas](docs/SCREENSHOTS.md)

## Instalação

### Instalar a partir de uma release

Baixe o ZIP ou TAR.GZ em [Releases](https://github.com/dsrsouza/Oger-Dock/releases), extraia o pacote e execute o instalador **dentro da pasta extraída**. A instalação compila os componentes C++/Qt6/KF6 localmente; **não** há um plasmoide universal pré-compilado nesse pacote.

### Dependências de compilação por distribuição

Para compilar a versão 1.0.0, são necessários **CMake 3.22+, compilador C++20, Qt 6.6+, KDE Frameworks 6, Plasma/PlasmaQuick 6, Plasma Activities/ActivitiesStats, LibKWorkspace, cabeçalhos PipeWire 0.3, ECM, Gettext e Qt Shader Baker (`qsb`)**. Esses requisitos foram conferidos nos arquivos CMake do Oger Dock.

Execute **somente o comando da sua distribuição**. Nomes de pacotes e versões podem variar; as listas indicam dependências para compilar o projeto e **não** significam homologação da versão final em todas as distribuições.

<details>
<summary>openSUSE Tumbleweed / Leap com Plasma 6 compatível</summary>

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

</details>

<details>
<summary>Fedora KDE</summary>

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

</details>

<details>
<summary>Debian / Ubuntu / Kubuntu / KDE neon com Plasma 6</summary>

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

</details>

<details>
<summary>Arch Linux / Manjaro com Plasma 6 compatível</summary>

```bash
sudo pacman -Syu --needed \
  base-devel binutils cmake extra-cmake-modules gettext git pkgconf \
  qt6-base qt6-declarative qt6-shadertools \
  kconfig kcoreaddons kglobalaccel ki18n kjobwidgets kio \
  kpackage kservice kwindowsystem \
  libplasma plasma-workspace plasma-activities plasma-activities-stats \
  pipewire unzip zip
```

</details>

Depois de instalar os pacotes, execute `bash scripts-user/setup.sh --check-deps` na **pasta do código-fonte completo e extraído**. **Atenção:** essa opção verifica somente **parte** das dependências exigidas pelo CMake, sobretudo no openSUSE. O comando pode indicar que está tudo instalado e, ainda assim, o CMake solicitar outro pacote.

Veja as explicações e soluções no [guia completo de instalação](docs/INSTALACAO.pt_BR.md).

### Compilar pelo código-fonte

Para baixar e compilar o código-fonte completo:

```bash
git clone https://github.com/dsrsouza/Oger-Dock.git
cd Oger-Dock
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

Execute como usuário comum do desktop, não como root. Depois, em **Adicionar widgets** do KDE Plasma, escolha **Oger Dock**. Para carregar o módulo nativo atualizado, talvez seja necessário sair e entrar novamente na sessão. **Não apague as configurações existentes na atualização.**

Veja as dependências por distribuição no [guia em português](docs/INSTALACAO.pt_BR.md) e no [guia em inglês](docs/INSTALLATION.md).

## Compatibilidade

| Ambiente | Situação |
|---|---|
| openSUSE Tumbleweed / KDE Plasma 6.8.2 / Wayland | Principal ambiente de desenvolvimento e testes do usuário |
| Outras distribuições com KDE Plasma 6 compatível | Alvo previsto; requer compilação e validação |
| Fedora KDE | Instruções disponíveis; homologação da release pendente |
| Debian / Ubuntu KDE | Instruções disponíveis; homologação da release pendente |
| Ambientes sem KDE Plasma | Não suportados |

O **nome público** é Oger Dock. O identificador técnico `org.kde.plasma.punchi-dock-remastered` foi preservado para manter as preferências e a compatibilidade das atualizações. Mudanças em bibliotecas Qt ou Plasma podem exigir recompilação.

## Testes e qualidade

Na preparação da versão 1.0.0, foram registrados **11/11 testes de regressão direcionados** e **13/13 verificações de sintaxe Shell** aprovados. São verificações locais que **não** substituem compilação nativa nem testes completos em todas as distribuições. A correção da R63.7 que impede a ativação indevida do MEGA durante o scroll foi confirmada no KDE Plasma.

Mais informações: [Notas da versão](docs/RELEASE-1.0.0.md) · [Arquitetura](docs/ARCHITECTURE.md) · [Perguntas frequentes](docs/FAQ.md).

## Comunidade e suporte

- **Ajuda, dúvidas e ideias:** [GitHub Discussions](https://github.com/dsrsouza/Oger-Dock/discussions) *(deve ser ativado nas configurações do repositório)*.
- **Erros e solicitações de recursos:** [GitHub Issues](https://github.com/dsrsouza/Oger-Dock/issues).
- **Contribuições:** [Guia de contribuições](CONTRIBUTING.md) e [política de segurança](SECURITY.md).

Em relatórios de erros, informe distribuição, versões do Plasma/Qt, Wayland/X11, instalação, passos de reprodução e logs sem dados pessoais.

<details><summary>Estrutura do código-fonte</summary>

```text
contents/       interface QML, JavaScript, imagens e configurações
src/            componentes nativos C++
scripts-user/   dependências, compilação, empacotamento e instalação
tests-dev/      testes direcionados de regressão
po/             traduções
metadata.json   metadados do plasmoide
AGENTS.md       orientações de desenvolvimento e IA
```

</details>

### Desenvolvimento assistido por inteligência artificial

Ferramentas de IA auxiliaram na pesquisa, implementação, investigação de regressões, testes e documentação. A revisão técnica e a validação final continuam sob responsabilidade dos mantenedores. O histórico de alterações registra as decisões do desenvolvimento.

## Créditos

**Diego Souza.R**  
**Punchisoft**

O Oger Dock tem como base o [Punchi Dock Remastered](https://github.com/PunchiSoft/punchi-dock-remastered), desenvolvido por **PunchiSoft**. Os avisos originais de direitos autorais e as obrigações de atribuição permanecem aplicáveis; consulte [NOTICE](NOTICE).

## Licença

Distribuído sob a [GNU General Public License v3.0 ou posterior](LICENSE). Consulte o arquivo [NOTICE](NOTICE) e preserve os créditos, avisos originais e a disponibilidade do código-fonte correspondente nas redistribuições.
