# Publicar o Oger Dock 1.0.0

O GitHub já possui o README bilíngue, documentação, licença e os modelos de contribuição. **A importação do código-fonte e a criação da release só ocorrerão após o envio do ZIP de publicação.**

1. Baixe o arquivo `Oger-Dock-1.0.0-Instalador-Publicacao.zip` preparado para esta versão.
2. Acesse [Code → Add file → Upload files](https://github.com/dsrsouza/Oger-Dock/upload/main).
3. Envie o ZIP **fechado**, com esse nome exato, na raiz da branch `main`, e confirme o commit.
4. Confira a ação [Import Oger Dock 1.0.0 source installer](https://github.com/dsrsouza/Oger-Dock/actions).
5. Somente após a conclusão com sucesso, confirme que `contents/`, `src/`, `scripts-user/`, `po/`, testes e outros arquivos foram importados. O ZIP da aba Code deverá desaparecer.
6. A automação poderá criar a tag `v1.0.0` e a release com instaladores e hashes, caso a permissão de Actions permita gravação em `Contents`.

### Integridade

O importador usa o SHA-256 **fixo** `553b6561ffb3e8dec06b98fa415371e550b2a7c7236c8717fcad3be5e2383a96` para não aceitar um arquivo diferente por engano.

### Se não executar

Em **Settings → Actions → General**, confira se as Actions estão habilitadas e se a política de permissão do `GITHUB_TOKEN` permite a gravação exigida pelo fluxo. Não desative verificações de hash nem sobrescreva manualmente arquivos para contornar falhas. Compartilhe o log da execução para diagnóstico.

### Concluir a página

Ative **Settings → General → Features → Discussions** para habilitar o link de suporte. Adicione apenas capturas reais, seguindo [SCREENSHOTS.md](SCREENSHOTS.md). A compilação/validação nativa final permanece uma etapa de homologação.
