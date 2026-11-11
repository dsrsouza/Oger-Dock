# Oger Dock — Instruções para IAs e mantenedores

Este arquivo descreve as regras de desenvolvimento aprovadas até o lançamento **1.0.0 (base R63.7)**. Leia também `docs/IA-HISTORICO-CORRECOES.md` e `docs/IA-TESTES-E-SEGURANCA.md` antes de modificar código.

## Regras inegociáveis

1. **Autorização:** quando estiver colaborando com o usuário original neste projeto, faça diagnóstico e apresente proposta, mas só modifique o código após a autorização textual **“pode fazer as correções”**. Não interprete aprovação de análise como autorização para editar.
2. **Preservar dados instalados:** o nome mostrado é *Oger Dock 1.0.0*, mas `KPlugin.Id = org.kde.plasma.punchi-dock-remastered`, o URI `org.punchi.dock`, o domínio i18n `plasma_applet_org.kde.plasma.punchi-dock-remastered`, caminhos antigos de armazenamento e tipos serializados continuam por compatibilidade. **Não renomear em massa.** Uma migração exigiria testes de leitura/escrita/rollback próprios.
3. **Compatibilidade:** alvo principal openSUSE Tumbleweed, KDE Plasma 6.8.2, Qt 6, KF6 e Wayland; evitar supor que X11/Wayland têm a mesma semântica de janelas e popups.
4. **Baseline R63.7:** o scroll é sequencial e sem circularidade; *apps iniciados automaticamente que permanecem só na tray não entram na sequência nem recebem Activate por scroll*. Apps fixados e explicitamente promovidos seguem regras próprias. Não regredir o leque fluido, a nitidez de mosaicos, o tray SNI, o mini-player nem os menus.
5. **MEGA/StatusNotifierItem:** o Plasma chama o aplicativo ao clicar na tray superior. A dock não recebe diretamente esse clique; **não tentar reposicionar popups externos à força**. A solução KWin R63.2 foi rejeitada após testes reais e removida. Ativação SNI não garante toggle nem posicionamento. No hover de um item temporário da tray **não abrir prévia/tooltip de janela**; proteger o fluxo `temporaryTrayId` completo.
6. **Pastas:** cores individuais existem em `dockItemsJson` (`folderAccentColor`), cores padrão de categoria em `folderCategoryColorsJson`. Uma cor individual prevalece. A interface deve listar pastas reais, mesmo com nomes repetidos, preservando entradas alheias ao salvar. Não confundir categoria padrão e pasta criada manualmente.
7. **KCM:** manter `cfg_` no KConfig, e Aplicar/OK/Cancelar corretos. Carregar as páginas independentemente para evitar regressão de lentidão. Não reintroduzir inicialização incremental de Itens (R62.5 fez a prévia desaparecer). Não alterar efeitos/animações como substituto de diagnóstico.
8. **Escopo reduzido:** evitar refatorações generalizadas e mudanças simultâneas de runtime C++, plugins, UI e persistência. Cada correção deve ter teste de regressão cobrindo **fluxo real de dados até o componente visual**, não apenas a presença de um nome no arquivo.
9. **Licença e créditos:** GPL-3.0-or-later; preservar `NOTICE`, copyrights e atribuição histórica ao Punchi Dock Remastered/PunchiSoft. O nome atual e autores da UI são `Diego Souza.R` e `Punchisoft`, separados.
10. **Honestidade técnica:** se ECM/KF6 ou Plasma real não estão disponíveis, relatar exatamente os testes que passaram e marcar compilação/homologação como pendentes. Não declarar funcionamento ou aumento de desempenho comprovado apenas com testes estáticos.

## Antes de gerar pacotes

- Verificar `metadata.json`, `CMakeLists.txt`, fontes de tradução `po/en.po`, `po/pt_BR.po`, `po/es.po`, `po/de.po`, `NOTICE` e documentação.
- Executar testes recentes e rodar `bash -n` nos scripts. Em máquina com dependências, executar `bash scripts-user/setup.sh --check-deps` e `--build-only -j 2`; validar o `.plasmoid` gerado e a atualização sem apagar preferências.
- Comprovar que o scroll não mostra o popup do MEGA quando ele está só na tray; testar hover, clique/Voltar para a tray, configurações de pastas, seleção múltipla, leque, mini-player e navegação de categorias.
- Não inserir `scripts-dev` ou verificações obrigatórias que dependam de arquivos que não estão no pacote. O instalador do usuário usa o modo de compilação local *minimal*.
- Nunca apagar a configuração do usuário como etapa de atualização. Manter caminho de retorno para uma versão anterior.

## Arquivos de referência

- `docs/IA-HISTORICO-CORRECOES.md`: decisões, bugs, tentativas rejeitadas e sintomas.
- `docs/IA-MAPA-TECNICO.md`: componentes, dados e pontos sensíveis.
- `docs/IA-TESTES-E-SEGURANCA.md`: matriz de testes e política de releases.
- `CHANGELOG.md`, `HISTORICO_ALTERACOES.md`, `ALTERACOES_ATUAIS.md`: cronologia e estado de revisão.

**Não confunda estas orientações de manutenção com permissões para modificar automaticamente uma instalação.**
