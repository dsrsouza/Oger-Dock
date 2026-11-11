# Instalando o Oger Dock 1.0.0

Este guia utiliza a compilação **local**, para que os componentes nativos sejam construídos com as bibliotecas Qt/KDE do próprio computador. O código-fonte completo **já está publicado na branch `main`**, e os pacotes do instalador estão disponíveis na área [Releases](https://github.com/dsrsouza/Oger-Dock/releases).

## 1. Verifique seu ambiente

Abra um terminal dentro da sessão KDE Plasma e confira:

```bash
plasmashell --version
qmake6 -query QT_VERSION 2>/dev/null || true
```

O desenvolvimento e os testes funcionais principais foram feitos no **openSUSE Tumbleweed com Plasma 6.8.2 e Wayland**. Fedora e Debian/Ubuntu são alvos previstos, mas a compilação e a interface precisam ser verificadas em cada sistema.

## 2. Prepare as dependências

O Oger Dock 1.0.0 exige **CMake 3.22+, C++20, Qt6 6.6+, KF6 6.0+, Plasma 6.0+, PlasmaQuick, Activities, ActivitiesStats, LibKWorkspace, ECM, Gettext, cabeçalhos PipeWire 0.3, pkg-config e `qsb` (Qt Shader Baker)**. As listas foram conferidas no `CMakeLists.txt` e no `src/CMakeLists.txt` do instalador.

**Instale apenas os pacotes da sua distribuição.** Os nomes podem mudar entre versões e as listas não constituem homologação da versão final em todos os sistemas. Não misture repositórios nem force downgrade do Qt/KDE.

### openSUSE Tumbleweed / Leap com Plasma 6 compatível

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

Se algum pacote não for localizado, consulte `zypper search <nome-do-pacote>`. Na versão atual, `--check-deps` verifica **apenas parte** dos pacotes de desenvolvimento no openSUSE, então use a lista completa acima.

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

### Debian / Ubuntu / Kubuntu / KDE neon com Plasma 6

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

É necessário que a versão da distribuição disponibilize Plasma 6 e os arquivos de desenvolvimento compatíveis. Instalar somente esses nomes não transforma um Plasma 5 em ambiente suportado.

### Arch Linux / Manjaro com Plasma 6

```bash
sudo pacman -Syu --needed \
  base-devel binutils cmake extra-cmake-modules gettext git pkgconf \
  qt6-base qt6-declarative qt6-shadertools \
  kconfig kcoreaddons kglobalaccel ki18n kjobwidgets kio \
  kpackage kservice kwindowsystem \
  libplasma plasma-workspace plasma-activities plasma-activities-stats \
  pipewire unzip zip
```

Os nomes são os dos repositórios Arch. No Manjaro, a disponibilidade depende do ramo de atualizações e das versões do sistema.

### Verificação de dependências

Depois de extrair o pacote completo, na pasta do projeto:

```bash
bash scripts-user/setup.sh --check-deps
```

**Atenção:** essa opção testa somente um **subconjunto** das dependências reais do CMake. Ela pode não identificar tudo o que falta, principalmente no openSUSE. A configuração e a compilação do projeto são a verificação definitiva; uma verificação prévia sem erros não equivale a uma instalação funcional.

## 3. Baixe, compile e instale

Com o código-fonte completo já publicado:

```bash
git clone https://github.com/dsrsouza/Oger-Dock.git
cd Oger-Dock
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

Se estiver usando o ZIP/TAR.GZ do instalador, extraia-o, entre na pasta extraída e execute os três comandos `bash scripts-user/...` ali. Não é necessário fazer `git clone` quando o instalador completo já foi baixado.

O `-j 2` limita o uso de tarefas paralelas, recomendado para economizar memória. A compilação deve ser executada como usuário normal, não usando `sudo` antes do script.

## 4. Ative o widget

Na área de trabalho do KDE Plasma, abra **Adicionar widgets**, procure **Oger Dock** e adicione-o. Quando uma atualização substituir bibliotecas nativas que já estavam carregadas, encerre e reinicie a sessão do Plasma para testar a nova versão.

**Não apague** as configurações do plasmoide nem remova seus itens fixados durante a atualização. A continuidade utiliza um identificador interno preservado.

## 5. Solução de problemas

- **Dependências ausentes:** repita `bash scripts-user/setup.sh --check-deps` e confira o nome do pacote nos repositórios da sua versão.
- **CMake não encontra KF6/Plasma:** confira se as versões `-devel` correspondem às bibliotecas do sistema, sem misturar repositórios incompatíveis.
- **O widget aparece vazio após uma atualização:** feche a sessão, entre novamente e faça uma compilação local com as bibliotecas atuais.
- **Erro só no Wayland ou em um aplicativo de bandeja:** registre a distribuição, Plasma, Qt e os passos para reproduzir; algumas funções dependem de informações expostas pelo KDE e pelo próprio aplicativo.

Para ajuda, utilize [GitHub Discussions](https://github.com/dsrsouza/Oger-Dock/discussions) (após ativação) ou abra um [Issue](https://github.com/dsrsouza/Oger-Dock/issues).