# Instalando o Oger Dock 1.0.0

Este guia utiliza a compilação **local**, para que os componentes nativos sejam construídos com as bibliotecas Qt/KDE do próprio computador. O código-fonte e o instalador completos precisam estar disponíveis; neste momento, o repositório contém apenas a documentação pública; use o instalador completo da área Releases assim que for disponibilizado.

## 1. Verifique seu ambiente

Abra um terminal dentro da sessão KDE Plasma e confira:

```bash
plasmashell --version
qmake6 -query QT_VERSION 2>/dev/null || true
```

O desenvolvimento e os testes funcionais principais foram feitos no **openSUSE Tumbleweed com Plasma 6.8.2 e Wayland**. Fedora e Debian/Ubuntu são alvos previstos, mas a compilação e a interface precisam ser verificadas em cada sistema.

## 2. Prepare as dependências

As listas abaixo partem dos componentes usados pelo projeto de referência KDE Plasma 6. São **orientações iniciais**, não uma certificação de que cada pacote existe com exatamente o mesmo nome em todas as versões. Verifique as dependências reais da versão publicada com `bash scripts-user/setup.sh --check-deps`. Não substitua pacotes instalados forçadamente para fazer uma dependência funcionar.

### openSUSE Tumbleweed

```bash
sudo zypper refresh
sudo zypper install \
  git cmake make gcc-c++ binutils gettext-tools pkgconf-pkg-config \
  kf6-extra-cmake-modules \
  qt6-base-devel qt6-declarative-devel qt6-shadertools \
  kf6-kconfig-devel kf6-kcoreaddons-devel kf6-kglobalaccel-devel \
  kf6-ki18n-devel kf6-kjobwidgets-devel kf6-kio-devel \
  kf6-kpackage-devel kf6-kservice-devel kf6-kwindowsystem-devel \
  libplasma6-devel plasma6-workspace-devel \
  plasma6-activities-devel plasma6-activities-stats-devel \
  pipewire-devel unzip zip
```

### Fedora KDE

```bash
sudo dnf install \
  git cmake make gcc-c++ binutils gettext pkgconf-pkg-config \
  extra-cmake-modules \
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtshadertools \
  kf6-kconfig-devel kf6-kcoreaddons-devel kf6-kglobalaccel-devel \
  kf6-ki18n-devel kf6-kjobwidgets-devel kf6-kio-devel \
  kf6-kpackage-devel kf6-kservice-devel kf6-kwindowsystem-devel \
  libplasma-devel plasma-workspace-devel \
  plasma-activities-devel plasma-activities-stats-devel \
  pipewire-devel unzip zip
```

### Debian / Ubuntu com KDE Plasma 6

```bash
sudo apt update
sudo apt install \
  git build-essential cmake binutils gettext pkg-config \
  extra-cmake-modules \
  qt6-base-dev qt6-base-dev-tools qt6-declarative-dev \
  qt6-declarative-dev-tools qt6-shader-baker \
  libkf6config-dev libkf6coreaddons-dev libkf6globalaccel-dev \
  libkf6i18n-dev libkf6jobwidgets-dev libkf6kio-dev \
  libkf6package-dev libkf6service-dev libkf6windowsystem-dev \
  libplasma-dev plasma-workspace-dev \
  libplasmaactivities-dev libplasmaactivitiesstats-dev \
  libpipewire-0.3-dev unzip zip
```

**Importante:** distribuições com KDE Plasma 5 ou bibliotecas KDE/Qt insuficientes não ficam compatíveis somente com a instalação desses nomes de pacotes. O resultado final depende das versões efetivamente disponíveis nos repositórios da distribuição.

## 3. Baixe, compile e instale

Depois que os arquivos completos estiverem publicados:

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