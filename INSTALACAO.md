# Instalação e atualização — Oger Dock 1.0.0

O ZIP/TAR.GZ é um **kit completo de código-fonte e instalação local**. Ele **não contém o `.plasmoid` compilado**: o próprio computador compila o módulo nativo com as bibliotecas Qt6, KF6, ECM e KDE Plasma correspondentes à distribuição.

## openSUSE Tumbleweed / KDE Plasma 6.8.2

1. Extraia o arquivo `Oger-Dock-1.0.0-Instalador.zip` para uma pasta comum (por exemplo, Downloads).
2. Abra o terminal dentro da pasta `Oger-Dock-1.0.0-Instalador`.
3. Verifique as dependências e instale os pacotes faltantes conforme as instruções mostradas pelo instalador:

```bash
bash scripts-user/setup.sh --check-deps
```

4. Compile e instale com paralelismo moderado:

```bash
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

5. Reinicie **a sessão KDE Plasma** (sair e entrar novamente) para recarregar o módulo nativo e os componentes de interface.

## Atualização a partir de R63.7 ou anteriores

O identificador do plasmoide foi preservado para reutilizar a configuração existente. **Não desinstale antes da atualização e não apague as preferências.** Recomenda-se fazer uma cópia de segurança das configurações do Plasma antes de instalar. O instalador produz `.plasmoid` local em `dist/` quando a compilação é bem-sucedida.

## Validação não destrutiva

```bash
bash tests-dev/run-release-regressions.sh
bash scripts-user/setup.sh --help
```

O primeiro comando executa testes Node.js (é necessário ter `node` instalado). O segundo exibe as opções disponíveis do instalador.

## Se faltar ECM/KF6

Uma falha do CMake em `find_package(ECM 6.0 REQUIRED)` indica ausência das dependências de desenvolvimento no sistema, não necessariamente erro no código-fonte. No openSUSE, use `--check-deps` e leia a lista específica exibida pelo script. Sem as dependências não é possível produzir um `.plasmoid` utilizável a partir do fonte.

## Idiomas

Interface e textos de instalação disponibilizados em inglês, português brasileiro, espanhol e alemão. O domínio interno `plasma_applet_org.kde.plasma.punchi-dock-remastered` foi mantido intencionalmente para compatibilidade com o KDE.

## Limitações de release

A regressão de scroll/tray do MEGA foi validada pelo usuário no Plasma na revisão R63.7. A marca 1.0.0 e as traduções são atualizações de metadados/empacotamento; exigem ainda compilação e validação visual finais no computador do usuário.

Para procedimentos de atualização e código por IA, consulte `AGENTS.md` e `docs/IA-TESTES-E-SEGURANCA.md`.
