# Publicar o Oger Dock 1.0.0 — guia do mantenedor

A documentação do Oger Dock já está na branch `main`. Para importar o código-fonte completo, utilize **um único ZIP** e a automação versionada em `.github/workflows/import-oger-dock-source.yml`.

## 1. Enviar o ZIP de publicação na aba Code

1. Baixe o arquivo **`Oger-Dock-1.0.0-Instalador-Publicacao.zip`** fornecido na conversa de preparação da release.
2. Abra [Oger-Dock](https://github.com/dsrsouza/Oger-Dock) → **Code → Add file → Upload files**.
3. Arraste o ZIP **fechado**, com o nome exato `Oger-Dock-1.0.0-Instalador-Publicacao.zip`, na raiz do repositório.
4. Escolha `main` e conclua em **Commit changes**.

**Atenção:** use apenas esse ZIP, não o instalador corrigido anterior, pois a automação verifica um SHA-256 específico:

```text
553b6561ffb3e8dec06b98fa415371e550b2a7c7236c8717fcad3be5e2383a96  Oger-Dock-1.0.0-Instalador-Publicacao.zip
```

## 2. Conferir a importação automática

Abra [Actions](https://github.com/dsrsouza/Oger-Dock/actions) e consulte **Import Oger Dock 1.0.0 source installer**. Se o fluxo concluir, o próprio GitHub fará o seguinte:

- Comparará o SHA-256 antes de extrair os arquivos.
- Importará o código-fonte completo e os scripts, preservando permissões do arquivo compactado.
- Manterá os READMEs bilíngues, guias publicados e licença já incluídos no repositório.
- Removerá o ZIP da raiz, deixando os arquivos fonte organizados na aba **Code**.
- Registrará um novo commit com a mensagem `release: import verified Oger Dock 1.0.0 source tree`.

Caso Actions esteja desativado ou a permissão de gravação dos workflows esteja bloqueada, a importação não será concluída: confira o erro antes de tentar novamente. Não remova manualmente arquivos do projeto para corrigir um erro de CI.

## 3. Criar a release

**Após confirmar que a importação foi concluída**, abra [New release](https://github.com/dsrsouza/Oger-Dock/releases/new).

- **Tag:** `v1.0.0` (nova tag apontando para `main` já com o código-fonte)
- **Título:** `Oger Dock 1.0.0`
- **Arquivos anexos:** `Oger-Dock-1.0.0-Instalador-Publicacao.zip`, `Oger-Dock-1.0.0-Instalador-Publicacao.tar.gz` e `Oger-Dock-1.0.0-Instalador-Publicacao-SHA256.txt`.
- **Descrição:** use [informações da versão 1.0.0](RELEASE-1.0.0.md).

Marque **Set as the latest release** se aplicável, depois clique em **Publish release**.

## 4. Finalização

- Habilite **Settings → General → Features → Discussions** para que o link de suporte funcione.
- Use capturas **reais** do aplicativo conforme [orientações de imagens](SCREENSHOTS.md).
- A release é um instalador em código-fonte: o `.plasmoid` é compilado localmente; não afirme distribuição de binário universal nem homologação em distribuições não testadas.
- Preserve a base R63.7 e a correção que impede ativação indevida do MEGA pelo scroll.
