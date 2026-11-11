## R63.7 — scroll não ativa aplicativos exclusivos da tray (candidata, 10/11/2026)

- `TaskModelController.qml::wheelCandidates()` filtra antes de qualquer ativação os aplicativos de terceiro identificados por autostart do usuário **e SNI real**, que ainda estão somente na bandeja. Isso vale para janelas no KDE TasksModel e notificadores sem janela.
- O filtro preserva aplicativos fixados, temporariamente promovidos da bandeja à dock, aplicativos comuns, e serviços do sistema não abrangidos pela política de autostart de usuário.
- Em caso de aliases SNI/KService, usa resolução de identidades existente, sem correspondência fuzzy por ícone/título.
- Evita que o scroll envie `SNI Activate` ao MEGAsync somente na bandeja; a proteção R63.4 contra promoção involuntária por foco continua preservada.
- Sequência de scroll mantém direção, limites sem wrap, restauração/minimização e ordem visual da R45/R63.6.
- Novo teste integrado `tests-dev/test-r63-7-wheel-tray-only.mjs` exercita candidatos reais, transição de janela, SNI, alias, pinned/promovido e remoção de identidade obsoleta durante gesto.
- Testes offline: Node **39/50**, com as mesmas 11 falhas legadas da R63.6; Bash `bash -n` **32/32**; ECM/KF6 indisponível para compilação. Revisão ainda não homologada no Plasma Wayland real.

## R63.6 — identidade da tray preservada na prévia dinâmica (candidata, 09/11/2026)

- **Causa comprovada da regressão R63.5:** `TaskModelController.qml::buildVisibleTaskEntryForRow()` colocava `temporaryTrayId` em `visibleTaskRows`, mas `taskDataForEntry()` descartava o campo ao criar o objeto usado por `main.qml`. Assim, mesmo com o MEGA promovido, `temporaryTrayPresentation` ficava falso e o hover disparava uma prévia que podia ocultar a janela do MEGA por perda de foco.
- `taskDataForEntry()` agora propaga `temporaryTrayId` nos retornos normais e nos fallbacks para entrada inválida/linha indisponível. Não altera o agrupamento, contadores, ordenação ou identidade dos demais aplicativos.
- O delegate dinâmico em `main.qml` consulta **primeiro a entrada visual original** (`modelData.temporaryTrayId`) e usa `taskData.temporaryTrayId` como fallback. A mesma identidade é usada para bloqueio de hover/tooltips, clique via SNI e ação nativa “Voltar para a tray”, evitando decisões inconsistentes.
- Novo teste `tests-dev/test-r63-6-tray-hover-integration.mjs` executa funções reais de modelo/projeção e handlers do delegate, testa app normal, popup MEGA, perda temporária de linha, clique e bloqueio de preview. Testes R63.3/R63.5 atualizados para referenciar o identificador compartilhado (sem relaxar seus contratos).
- R63.4 (pastas personalizadas e scroll isolado), SNI de terceiros e aplicativos fixados, leque, player e KCM não alterados. Não reintroduz o script KWin do MEGA.
- Testes offline: **38/49 Node PASS**, com exatamente as mesmas 11 falhas históricas da R63.5 (**37/48 PASS**); **32/32 scripts Shell PASS**; compilação CMake bloqueada antes da construção por ECM >=6.0 ausente. **Sem homologação Wayland real**; MEGA ainda pode auto-ocultar seu popup por razões externas à dock.

## Oger Dock R63.5 — clique alterna o popup do MEGA sem auto-ocultação por hover (candidata, 09/11/2026)

- Em `contents/ui/main.qml`, ícones dinâmicos temporários de aplicativos SNI/tray não disparam mais prévias de janelas nem controles de mídia ao passar o mouse; tooltips são suprimidos e solicitações de prévia pendentes são canceladas quando o item é promovido.
- Em `TaskModelController.qml`, `togglePromotedTrayApplication()` trata apenas identificadores já promovidos: MEGAsync prioriza `StatusNotifierItem.Activate(x,y)`, igual ao clique na tray nativa; demais programas usam `requestToggleMinimized`/`requestActivate` sobre janela existente e, na ausência de janela minimizável, o SNI do próprio aplicativo. Nunca cria segunda instância nem remove ícone por esconder janela.
- `Voltar para a tray`, SNI/DBusMenu, scroll sequencial sem promoção, pastas reais e cores R63.4, leque e player permanecem preservados.
- Novo teste `tests-dev/test-r63-5-mega-hover-toggle.mjs` valida proteção de hover, prioridade SNI do MEGA, alternância de janela normal, fallback e isolamento de tarefas. Compatibilidade Wayland real ainda precisa ser validada.

## R63.4 — pastas reais e isolamento do scroll da tray (candidata, 09/11/2026)

- **Pastas:** Configurações → Pastas passa a apresentar os nomes e as cores individuais `folderAccentColor` das pastas realmente existentes em `cfg_dockItemsJson` (fonte de verdade compartilhada com Itens). Antes a lista mostrava somente oito padrões de categoria, mesmo para pastas manuais.
- **Primeira instalação:** se não há pastas no JSON, continua mostrando os oito padrões. Quando há pastas, apresenta a lista real; botão específico permite alternar para **Editar padrões das categorias**, sem confundir cores por pasta com cores globais.
- **Edição segura:** alterar uma cor edita somente a pasta correspondente no JSON do KCM, com verificação de índice e nome, mantendo apps, layout, ordem, cores de outras pastas e o ciclo Aplicar/OK/Cancelar; sem gravação direta no disco. Categorias/tema continuam como herança quando não existe cor individual.
- **Tray/scroll:** a navegação pela roda do mouse continua restaurando janelas ou SNI existentes, mas a ativação originada por scroll não promove aplicativos de autostart (por exemplo, MEGAsync) à dock. A supressão acompanha o gesto e o foco; uma ativação posterior explícita ainda pode promover quando o TaskManager identifica uma janela.
- **MEGA temporário:** a renderização da tray já promovida permanece enquanto existir SNI real, mesmo quando o TaskManager perder a janela; ação Voltar para a tray continua sendo a forma intencional de escondê-la. Nenhum processo é encerrado por essa regra.
- Traduções pt_BR, es, de adicionadas para a nova seção; nenhum script KWin de MEGA é incluído.
- Teste novo `tests-dev/test-r63-4-real-folders-scroll.mjs` passou (pastas manuais, nomes repetidos, edição/reset, scroll TaskManager e SNI, promoção posterior); suíte Node 36/47 PASS (11 verificações de interfaces antigas), Shell 30/30. Não foi possível compilar localmente por ausência do ECM 6.0; resultado visual precisa ser confirmado no Plasma/Wayland.

## R63.3 — tray ↔ dock temporários; remoção da integração KWin do MEGA (CANDIDATA, 09/11/2026)

- Removidos do **novo instalador** o script KWin `org.oger.dock.mega-tray-popup` e o helper de instalação `mega-popup-kwin.sh`. O instalador desativa/remove somente a integração antiga que possuir marcador válido de propriedade da Oger Dock, preservando scripts não pertencentes ao projeto. Reinicie a sessão KDE para descarregar o script antigo.
- Aplicativos de **autostart do usuário** com identidade KDE verificada e SNI real: ao observar a passagem de sua janela ao primeiro plano **depois da inicialização**, `TaskModelController` mantém a entrada temporária na dock. SNI registrado por si só NÃO cria ícone. Apps KDE/sistema, pins, apps sem SNI e apps sem correspondência segura não são promovidos.
- Clique direito no ícone temporário mostra o menu nativo do SNI e a ação **Voltar para a tray**; mesmo se DBusMenu não exportar ações há uma opção local de retorno e acesso ao ContextMenu nativo. Retornar remove a entrada temporária e minimiza apenas janelas existentes minimizáveis, sem encerrar processos, iniciar cópias ou gravar configurações. Estado dura apenas a sessão.
- Janela `SkipTaskbar` reconhecida no TasksModel pode ser temporariamente exibida. Se o popup do MEGA **não for representado por uma janela gerenciável no TasksModel**, o clique no ícone da bandeja **nativa do Plasma** não é observável pela dock, então a promoção e o reposicionamento não são garantidos. Exibir ícone na dock também **não altera** geometria de janela externa.
- R62.8 páginas KCM e `cfg_`, R63.1 layout Pastas, leque, scroll, player, menus SNI e políticas de autostart preservados. Não há mudanças de C++ nem de instalação de regras KWin.
- Teste de promoção/transição e menu R63.3 PASS offline; compilação/Wayland precisam de homologação no openSUSE KDE 6.8.2.

## R63.2 — Posicionamento isolado do MEGA por KWin (09/11/2026; candidata)

- Nova integração opcional, distribuída junto da Oger Dock: `kwin-scripts/org.oger.dock.mega-tray-popup/`. O instalador a habilita apenas em sessão Wayland quando encontra MEGAsync instalado, sem exigir root nem alterar qualquer aplicação de sistema.
- KWin escuta `workspace.windowAdded` e sinais `windowShown`/`windowHidden` de janelas identificadas como MEGAsync; verifica identificador de aplicativo, geometria de popup, capacidade de movimentação, ponteiro próximo ao painel superior e limites do monitor antes de ajustar **apenas a posição** do popup. Não redimensiona, não move janelas normais, não mexe no tray KDE e não cria itens dinâmicos na dock.
- Sem polling ou scripts de fundo externos. Comandos independentes `scripts-user/mega-popup-kwin.sh status|enable|disable|remove`; opção também acessível em Configurações do Sistema > Gerenciamento de Janelas > Scripts do KWin. Desativação explícita é respeitada na próxima atualização da dock; remoção automática apenas após desinstalação da dock instalada pelo mesmo usuário.
- Limitação: o clique da bandeja nativa não é entregue à dock, então o KWin usa a posição **atual** do ponteiro junto ao painel, não a coordenada precisa do clique. Popups `xdg_popup` não gerenciáveis pelo KWin não podem ser movidos por esse script. Requer teste real em KDE Plasma 6.8.2/Wayland, inclusive reiniciar MEGAsync para registrar futuras janelas.
- Teste Node específico R63.2 com simulação de KWin PASS; teste do utilitário de instalação em XDG isolado PASS. API validada com documentação KDE 6.0+/scripts e exemplos KWin atuais; compilação/execução no KWin do usuário não disponível neste ambiente.

## R63.1 — alinhamento das cores de pastas + workaround reversível MEGA Wayland (candidata, 09/11/2026)

- **Pastas:** seção de cores das 8 categorias redesenhada em coluna centralizada de largura máxima `42 * Kirigami.Units.gridUnit`; cada linha apresenta categoria, amostra de cor, botão nativo com valor hexadecimal/Tema e Restaurar, sem distância de tela inteira nem `contentItem` personalizado. O caminho `cfg_folderCategoryColorsJson` e a restauração do tema permanecem inalterados.
- **MEGA na tray superior do KDE:** identificado relato upstream MEGAsync #1170 sobre popup deslocado em Plasma Wayland quando Qt usa XWayland. Incluído utilitário **OPCIONAL** `scripts-user/mega-wayland.py`, com ações `status`, `apply` e `restore`, que cria sobreposição apenas de lançadores MEGAsync nativos do usuário para usar `QT_QPA_PLATFORM=wayland`. Requer plugin Qt5 Wayland. Protege edições posteriores no rollback, não altera arquivos do sistema ou dos demais apps, e não é executado pelo instalador da dock.
- Não adicionada regra KWin global nem script que mova janelas indiscriminadamente. A posição final do MEGA depende da versão/empacotamento e precisa de confirmação após reiniciar o aplicativo.
- **Contratos KDE:** onze categorias KCM e 130 declarações `cfg_` preservadas, inclusive Aplicar/OK/Cancelar. Runtime da dock, autostart tray-only R62.7, menus nativos, leque, scroll, player, OgerMenu e ID técnico inalterados.
- **Testes offline:** Node 36/45 (nove históricos incompatíveis), Shell 30/30, teste R63.1 layout PASS e utilitário MEGA (aplicar/desfazer/proteção contra alterações) PASS. Sem compilação/validação visual no Plasma Wayland neste ambiente.

## R63.0 — correções visuais de Pastas e auditoria das opções (candidata, 09/11/2026)

- **Tradução:** categoria independente `Folders` agora usa contexto `@title:settings-category`, com `Pastas` em pt_BR, sem depender do contexto de categorias do launcher.
- **Cores das categorias:** linha de cada categoria passa a reservar largura explícita para botão de cor e Restaurar; seletor apresenta amostra e valor hexadecimal da cor definida, ou `Tema` quando segue Plasma. Corrigido corte/sobreposição de rótulos que aparecia na R62.8.
- **Persistência:** mantido o JSON `cfg_folderCategoryColorsJson`, com escolha pelo `ColorDialog` e remoção da cor explícita ao usar Restaurar. Nenhuma mudança nas 130 declarações `cfg_` das onze categorias.
- **Auditoria offline:** novo teste verifica todas as onze categorias KCM, os valores `cfg_` previstos no KConfig, preservação das propriedades da R62.9, lógica de escolher/restaurar cores e traduções.
- **MEGA na bandeja nativa:** posicionamento da janela aberta pelo painel superior do KDE não é controlado pelo Oger Dock. O código do KDE envia as coordenadas SNI ao MEGA e o app/KWin decide a geometria final; não inserir regra automática de reposicionamento de janela ou hack para outros apps. Ver `POSICIONAMENTO-MEGA-KDE.md` para solução por regra KWin específica e limitações.
- **Preservados:** carregamento rápido da R62.8, filtragem tray/autostart, mosaicos da dock e da prévia, leque, scroll, player, DBusMenu, ID do plasmoid e comportamento de Aplicar/Cancelar.

## R62.9 — ativação de apps de tray com coordenadas reais (candidata, 09/11/2026)

- Corrigido o acionamento de aplicativos de tray disparado pela própria dock: `TrayWindowBridge::activateDesktopEntry()` deixou de enviar sempre `Activate(0, 0)` e agora aceita coordenadas globais do ponto de clique.
- `main.qml` passa a mapear o centro visual do item (`dockItemDelegate` / `trayDockItem`) para coordenadas globais e repassa esses valores ao SNI, aproximando pop-ups e janelas ancoradas do ícone realmente clicado.
- A ativação sem âncora explícita (ex.: navegação por roda/atalhos internos) continua funcional com fallback seguro.
- Nenhuma mudança na política de apps iniciados com o sistema, no filtro de autostart de terceiros, em menus nativos DBusMenu ou nas categorias da central de configuração.
- Limitação importante: quando o usuário clica no ícone da bandeja do próprio painel do KDE (fora da dock), o posicionamento final ainda depende do host da bandeja do Plasma e/ou do aplicativo. Esta revisão corrige o caminho de ativação originado pela dock.
- Validação offline: teste Node `test-r62-9-tray-activation-position.mjs` PASS. Sem Plasma Wayland real neste ambiente para homologar o posicionamento visual final.

## R62.8 — Configurações com categorias nativas KDE (candidata, 09/11/2026)

- Substituída a mega categoria Aparência com StackLayout/5 abas internas por 5 KCMs independentes: Aparência (dock), Pastas, Menus, Prévias de janelas e Visualizador de áudio; 11 categorias totais no ConfigModel.
- Removidos proxies de Loader/sincronização manual entre controles de abas: 92 cfg_ antigos preservados em KCM root; 93 incluindo folderCategoryColorsJson. Ações Aplicar/OK/Cancelar continuam administradas pelo Plasma.
- `ConfigAspect.qml` reduzido de 2056 para 1106 linhas; 4 wrappers novos permitem instanciar somente a categoria selecionada.
- Corrigida tradução pt-BR da categoria Menus (antes 'Cardápios'). Nenhuma mudança no runtime dock, SNI/tray, mini-player, mosaicos, leque, scroll ou ID técnico do plasmoid.
- Testes: Node 35/42 (7 legados incompatíveis), shell 30/30, teste R62.8 e delimitadores QML OK. Sem ECM/KF6 para compilação e homologação de fluidez.

## R62.7 — Carregamento sob demanda e apps iniciados na bandeja (CANDIDATA — 09/11/2026)

- **Aparência:** 4 painéis grandes (prévia de janelas, pastas, menus, visualizador) passam a ser criados por `Loader` assíncrono somente quando visitados. `ConfigAspect.qml` mantém **67 propriedades `cfg_`** em `Loader`s permanentes; cada alteração de usuário sincroniza com a propriedade do KCM para preservar Aplicar/OK/Cancelar, sem carregar controles ocultos só para guardar valores. O painel principal da dock continua síncrono.
- **Diagnóstico:** `OgerDock Config [Aparência/<aba>] lazy-load-ms` só aparece quando o carregamento de uma aba interna excede 75 ms. Logs de construção KCM R62.6 continuam disponíveis para comparar tempos observados.
- **Apps de terceiros no autostart do usuário:** `SystemDiscovery` consulta exclusivamente `~/.config/autostart/*.desktop` (ou equivalente XDG de usuário) e monitora alterações com `QFileSystemWatcher`. A janela só é excluída da lista dinâmica quando há correspondência exata de identificador **e SNI real registrado**. Ícones fixados ficam na dock; serviços KDE/sistema e entradas globais em `/etc/xdg/autostart` não são ocultados automaticamente. A SNI do Plasma continua funcional e é atualizada após alterações. Não depende de título/ícone do aplicativo.
- **Preservados:** prévia de Itens R62.6, mosaicos R62.3, SNI/DBusMenu nativos, scroll, leque, player, indicadores, item fixado, KConfig e ID técnico do plasmoid. Sem gravação ou alteração das preferências de autostart do usuário.
- **Limitações:** programas iniciados por systemd user ou autostart *global* não são classificados automaticamente; dependem de uma opção explícita futura caso necessário. Os ganhos de fluidez precisam ser medidos em Plasma Wayland real; esta revisão não está homologada.

## R62.6 — restauração da prévia Itens e redução de custo de navegação (CANDIDATA, 08/11/2026)

- **Correção crítica da R62.5:** removida a construção incremental do modelo `ListModel` por timer de intervalo zero. O modelo visual de Itens volta a ser construído integral e sincronicamente após `Qt.callLater(loadItems)`, como na R62.4, garantindo que `itemModel.count` acompanhe `items.length` antes do fim do carregamento. Nenhum JSON de configuração é apagado; Apply/Cancelar continuam sob o KCM KDE.
- **Pastas sem ícones vazios:** apenas o `Loader` do componente de mosaico `FolderStackIcon.qml` é assíncrono; um fallback de ícone de pasta permanece visível até o mosaico estar pronto. Não há temporizador de montagem do modelo.
- **Navegação mais leve:** removidas as transforms/animações aplicadas às sete páginas KCM completas. A mudança de categoria não precisa animar uma árvore inteira de controles.
- **Cache restrito de JSON:** cópia isolada do último JSON válido do modelo de Itens, para evitar repetir parsing idêntico ao voltar à categoria. Cada leitura devolve um clone: alterações pendentes não vazam entre telas, instâncias ou sessões. O cache é invalidado por texto diferente, parsing inválido ou conteúdo maior que 1 MiB.
- **Diagnóstico de custos:** as sete páginas registram no log do Plasma somente configurações com inicialização/event loop superior a 75 ms; a página Itens também avisa quando a montagem do modelo excede esse limite. Não há polling nem gravações de arquivos pelo diagnóstico.
- **Preservação:** ID técnico anterior, dados da dock, paleta do Plasma, SNI, leque, mini-player, scroll, pastas, atalhos, ícones e runtime C++ mantidos. A varredura incremental dos temas introduzida na R62.5 permanece, com cancelamento de execuções obsoletas.
- **Limitação:** sem Qt/KF6/ECM ou Plasma Wayland neste ambiente, não é possível medir FPS nem assegurar que a troca de categorias ficou suficientemente rápida. A R62.6 requer instalação e medição pelo usuário.

## R62.5 — carregamento real das páginas KCM em etapas (CANDIDATA, 08/11/2026)

- **Itens:** atualização inicial da projeção `ListModel` em lotes de seis ícones por quadro, preservando tamanho uniforme, ordem e edição/persistência síncronas em ações subsequentes. Edição pendente só abre após o carregamento visual completo.
- **Aparência:** `DockThemeRepository` agenda uma varredura incremental e cancelável de temas JSON, com até oito entradas/turno e orçamento aproximado de 5 ms. Resumos validados inalterados reutilizados de cache global limitado a 512; publica resultado somente após scan integral.
- **Remoção de temas:** reconciliação do tema selecionado após o novo sinal C++ `themesRefreshFinished`, sem comparar uma lista antiga com arquivos já removidos.
- **Transição:** removida a transparência da página inteira da R62.4. Restou deslocamento visual pequeno (máximo 4 px / 100 ms), desabilitado quando as animações do Plasma estão desativadas.
- **Preservação:** sete KCM nativos, `cfg_`/Aplicar/Cancelar, ID do plasmoid, folders, scroll, SNI/DBusMenu, leque, mini player, OgerMenu e instalador mantidos.
- **Validação:** 35/39 testes Node aprovados (4 legados obsoletos R56/R57), 30/30 Shell. Sem Qt/ECM para compilação e Wayland para medir FPS: **não homologada**. Consulte `LEIA-ME-R62.5.md` e `AUDITORIA-DESEMPENHO-R62.5.md`.

## R62.4 — Transições KDE suaves e auditoria de gargalos (CANDIDATA, 08/11/2026)

- As sete páginas `ConfigCategory` continuam sendo KCM nativos e passaram a usar `components/ConfigPageEntrance.qml`: entrada com fade de opacidade 0,94→1 e deslocamento visual de um `smallSpacing` até 0 em até 160 ms; **sem animação** quando `Kirigami.Units.longDuration` indica movimento desativado. Não bloqueia clique, não muda geometria/layout e não recria as páginas por conta própria.
- `SystemDiscovery` deixa de refazer imediatamente a consulta ao catálogo KDE para cada sinal `KSycoca::databaseChanged`: invalida na hora, agenda **um** recarregamento após a rajada somente se o catálogo estava carregado, mantendo o caminho sob demanda quando não estava.
- `DockThemeRepository` mantém uma cache **por instância e limitada aos arquivos presentes** de metadados de temas JSON validados, identificada por caminho/tamanho/mtime; arquivos alterados continuam passando por validação. Não altera renderizador ou valores de tema. A varredura de diretórios ainda é síncrona e precisa de aferição no KDE real.
- `RecentApplicationsController` agrupa notificações `TasksModel` antes de resolver identidades para a lista de recentes. Não altera SNI, sincronização de janela, roteamento do scroll, proteção pre-popup R45 ou lançamento dos apps.
- Auditoria de código cobrindo configuração, catálogo, temas, tarefas, pastas, SNI, menu, MPRIS, escrita de preferências, integrações e scripts; conclusões e itens pendentes em `AUDITORIA-DESEMPENHO-R62.4.md`.
- **Não homologada**: sem acesso a Qt/KF6/QML/KWin/Wayland para compilar ou medir tempos de troca e FPS. Não reivindicar ganhos medidos. Base R62.3 mantida para reversão.

## R62.3 — pastas idênticas na dock e na prévia de Itens (CANDIDATA, 08/11/2026)

- **Mesmo renderizador de pastas:** o editor da página Itens usa `contents/ui/components/FolderStackIcon.qml`, o componente da dock real, em vez de desenhar ícones estáticos. Mostra até quatro ícones reais da pasta em mosaico 2×2, placa/borda colorida e fallback do ícone quando vazia.
- **Cores em única implementação:** novo helper puro `contents/code/folderAccent.js` alimenta `DockItem.qml` e `ConfigItemsMainView.qml` com idêntica precedência: cor da própria pasta > cor KDE de categoria escolhida > paleta de categoria padrão > realce atual do Plasma. `cfg_folderCategoryColorsJson` é lido pela página Itens sem persistir mudanças adicionais.
- **Desempenho:** `Loader.active` cria o componente visual apenas para pastas; não carrega um mosaico extra para todos os aplicativos. Não há descoberta de arquivos, polling ou operações de disco por ícone.
- **Interações preservadas:** seleção simples e múltipla, arrastar itens/grupos, duplo clique para editar, foco/teclado, Aplicar/OK/Cancelar e proteção do OgerMenu. ID técnico, backend C++, leque, SNI, scroll, mini-player e persistência permanecem.
- **Limitação:** a prévia mostra os aplicativos já configurados no modelo da pasta, assim como a dock, e não consulta o catálogo em tempo real. Teste gráfico no KDE Plasma 6.8.2/Wayland é obrigatório. Ver `LEIA-ME-R62.3.md`.

## R62.2 — OgerMenu, olhos na cor do Plasma e troca de categorias mais leve (CANDIDATA, 08/11/2026)

- Corrigido **PunchiMenu** como rótulo visível para **OgerMenu**, incluindo configurações antigas: conversão apenas na exibição, mantendo o tipo técnico `punchimenu` e o ID de plasmoide para preservar dados dos usuários.
- Adicionada camada vetorial somente sobre os dois olhos do símbolo oficial, ativada **apenas com o menu aberto**, na cor de realce `Kirigami.Theme.highlightColor` do Plasma; mudança de tema altera a cor automaticamente.
- A camada dos olhos é carregada apenas no item do menu por `Loader`, evitando criar objetos QtQuick.Shapes para cada aplicativo. O desenho original e ícones personalizados são preservados.
- **Fluidez das opções laterais:** removidas varreduras redundantes da biblioteca de temas ao construir a página Aparência e ao mudar a pasta de temas, pois o `DockThemeRepository` já executa essa atualização no construtor e nos setters C++. A página Itens adia a reconstrução inicial do modelo para a próxima iteração do event loop, liberando antes a construção da página.
- Sem alteração do menu, SNI/tray, mini-player, persistência ou ID de configuração. Resultados da percepção visual exigem confirmação real no Plasma 6.8.2/Wayland. Ver `LEIA-ME-R62.2.md` e `TESTES-R62.2.txt`.

## R62.1 — correções de integração e identidade Oger Dock (08/11/2026) — CANDIDATA

- **GitHub correto:** `https://github.com/dsrsouza/Oger-Dock`; ajuda: `https://www.reddit.com/r/OgerDock/`. Metadados `KPlugin` com **Diego Souza Rego e Punchisoft** exatamente no campo de autores.
- **Logo do widget:** extração fiel da arte enviada, removendo o fundo quadriculado realmente embutido no JPEG e preservando transparência RGBA no PNG distribuído. O ícone monocromático do menu permanece com contorno legível.
- **Adicionar item:** volta ao formulário tradicional; o catálogo KDE fica acessível pelo botão **Procurar** do campo **Comando**, com seleção única e preenchimento automático. Não introduz um fluxo de adição paralelo nem perde dados do rascunho no Cancelar.
- **Editar item existente:** mesmo botão **Procurar** no formulário do item; resultado limitado ao aplicativo em edição, com verificação do índice selecionado para não alterar outro item.
- **Múltiplo arraste:** pilha de ícones com afastamento visível e contador, correção do índice obrigatório no delegado QML e da identidade dos itens; mantém a operação atômica e os testes de 15.718 permutações. Ícones personalizados do menu são respeitados.
- **Traduções:** nomes e textos visíveis da identidade atualizados e novas traduções contextuais pt-BR, es e de. Instaladores de usuário anunciam Oger Dock; identificadores técnicos e dados de configuração permanecem intactos.
- **Testes offline:** regressões R58–R61 e R62.1 passaram, além de verificação estrutural do QML, Bash e catálogos `.po`. Sem Qt/KF6 neste ambiente; **homologação gráfica no KDE real pendente**.

## R62 — rebranding para Oger Dock + gesto coletivo mais claro + atalho visual no comando (CANDIDATA, 08/11/2026)

- **Nova identidade visual nas superfícies principais:** `metadata.json` passa a exibir **Oger Dock**, com autores **Diego Souza Rego** e **Punchisoft**, site `https://github.com/PunchiSoft/oger-dock`, ajuda via `https://www.reddit.com/r/ogerdock/` e novo ícone do widget em `contents/images/oger-dock-widget.png`.
- **Ícone/menu Oger Dock:** o item interno `punchimenu` mantém compatibilidade técnica, mas agora se apresenta ao usuário como **Oger Dock** e usa o novo ícone estilizado `contents/images/oger-menu-symbolic.png` tanto na dock real quanto na prévia da página Itens.
- **Arraste múltiplo visualmente mais coerente:** ao arrastar uma seleção múltipla na página Itens, os demais elementos do grupo passam a acompanhar visualmente o item líder por meio de uma pilha/ghost animada, enquanto os itens de origem ficam atenuados. A mudança continua transacional, preservando ordem, seleção e Aplicar/Cancelar KDE.
- **Adicionar aplicativo sem perder a tela anterior:** o fluxo manual continua como tela principal do diálogo Adicionar item. No campo **Comando**, foi adicionado o botão **Browse**, que abre o catálogo visual KDE para escolher um aplicativo instalado e preencher automaticamente nome, descrição, ícone e comando do item em edição.
- **Catálogo contextual:** quando invocado pelo novo botão do campo Comando, o catálogo entra em modo de seleção única (**Use selected**) e volta diretamente ao rascunho atual; quando invocado para a dock/pastas manuais, mantém seleção múltipla e comportamento anterior.
- **Preservação:** IDs internos, storage/config, KCM, runtime C++, regras de SNI, mini-player, scroll, lixeira e demais bases aprovadas permanecem inalterados.
- **Pendente:** validação visual e gestual real no openSUSE Tumbleweed / KDE Plasma 6.8.2 / Wayland. Ver `LEIA-ME-R62.md`.

## R61 — Seleção múltipla e catálogo visual de aplicativos (CANDIDATA, 08/11/2026)

- Clique direito na prévia marca/desmarca vários ícones; arraste um marcado para mover o grupo numa única operação, mantendo ordem interna e Aplicar/Cancelar KDE. Conteúdo selecionado não é apagado em massa.
- Catálogo de aplicativos KDE com ícones reais, busca, categorias e múltipla seleção agora é a primeira opção do botão Adicionar item e do + em pastas manuais; comando manual permanece disponível.
- Reutiliza `SystemDiscovery`/`KApplicationTrader` já existentes e adiciona testes de 15.718 combinações de arraste, sem alterar runtime da dock ou backend C++.
- Pendente: validação gráfica e de gestos no Plasma 6.8.2/Wayland; ver `LEIA-ME-R61.md`.

## R60 — Central de configurações acompanha o tema KDE Plasma (CANDIDATA, 08/11/2026)

- Eliminado gradiente baseado em canais RGB multiplicados da prévia Itens; substituído por mistura proporcional entre cores `Kirigami.Theme.View` de fundo, texto e destaque.
- Fundo, bordas e hover se adaptam ao esquema claro/escuro e à cor de destaque do usuário, sem skin estático ou escolha de tema separada. Controles e diálogos nativos já herdam os controles do KDE.
- Não modifica temas personalizados da dock, dados, SNI, TaskManager, mini-player ou gestos.
- A validação visual e atualização dinâmica em Plasma 6.8.2/Wayland estão pendentes. Ver `LEIA-ME-R60.md`.

## R57.1 — conteúdo real de pastas no inspetor (CANDIDATA, 08/11/2026)

**Feedback KDE R57:** ao selecionar Software CAD, a prévia mostra blocos genéricos em vez de BIMCraft, FreeCAD e IngeTrazo. Causa comprovada no código: `FolderLayoutPreview.qml` tinha quatro nomes de ícones fixos e não recebia `selectedItem.apps`.

**Alteração:** repassar os itens reais à prévia, mostrar ícones e nomes na visualização Leque/Grade/Lista/Detalhada e acrescentar lista somente leitura com os apps da pasta, contagem e estado vazio. Animações e persistência anteriores preservadas. **Pendente:** validar no KDE real, inclusive pastas vazias, pastas longas e todos os modos.

## R57 — reconstrução incremental da configuração (candidata em 08/11/2026)

**Estado:** implementação e testes offline concluídos, sem homologação no Plasma real. Ponto de partida: R56.1.

**Aprovado para teste, ainda não aprovado como padrão estável:** inspetor contextual Itens, pesquisa com índices preservados, edição rápida e reversível do nome, seletor e prévia do tipo de pasta, reordenação animada via `ListModel.move`, ajuda expansível, layout estreito do editor e prévia animada de ícones em Geral. Preservados `ConfigModel`, `main.xml`, `cfg_dockItemsJson`, sete diálogos e arquivos de runtime da dock.

**Pendente:** executar e homologar em KDE Plasma 6.8.2/Wayland; reconstruir progressivamente demais páginas e diálogos, validar escalas e movimento reduzido, evitar regressões de R55/R56. O teste antigo R56 sobre o painel de nota vazio foi substituído pelo novo requisito de inspetor, não regredido acidentalmente.

## R56 — correção da página em branco e arquitetura KCM nativa (candidata, não homologada)

- Reversão da alteração de estado de janela da R55, cuja versão exibiu página vazia no KDE real.
- Página Itens agora usa `KCM.AbstractKCM` para controlar a ListView e dimensionamento responsivo.
- Sete diálogos usam o overlay da janela principal via `Controls.Overlay.overlay`.
- A lista e o painel informativo passam a uma coluna quando o espaço do KCM é insuficiente.
- Os códigos das funções aprovadas da dock permanecem idênticos aos da R54.
- Validação real no Plasma 6.8.2 pendente; R55 não aprovada.

## R52 — formulários responsivos por conteúdo, sem exceções por tipo (2026-11-08) — CANDIDATA

- **Motivação:** após a R51, a adição de pastas passou a dimensionar bem, mas a edição de pastas existentes apresentava campos e rótulos com alinhamento/dimensionamento inadequados. O pedido é uma regra reutilizável para os próximos recursos.
- **Mesma lógica para adicionar/editar:** `adaptiveDialogSizing.js::preferredFormWidth` compõe medidas das seções efetivamente visíveis, dos rótulos e de campos aninhados. `ItemEditorPanel` calcula a maior coluna de rótulo e a largura intrínseca dos campos; `ItemActionEditor` expõe largura independente da ListView; os dois fluxos compartilham a coluna de rótulos. Não há condições fixas `folder ? 56 : app ? 48`.
- **Outros diálogos:** lixeira, calendário/relógio, player, PunchiMenu e Centro de Controle deixam de impor o teto de largura de 42 unidades (e limites no chamador); passam a respeitar o tamanho natural do painel de opções e o espaço disponível na KCM.
- **Overflow:** se o formulário exceder o espaço da tela, o diálogo respeita a janela pai e disponibiliza rolagem vertical/horizontal automaticamente; os botões de ação permanecem acessíveis. Sem puxadores de resize manual.
- **Preservação:** coordenador de hover entre pastas de R51 aprovado pelo usuário, TaskManager R45, ícones 2x R47, menu 35ms R49, SNI, scroll, player, lixeira e persistência dos itens inalterados.
- **Validação:** testes Node offline e checks de integridade concluídos; a interface ainda depende de teste visual no KDE Plasma 6.8.2. R49 continua como referência funcional anterior; R51 tem a troca por hover validada pelo usuário. Ver `LEIA-ME-R52.md`.

## R51 — hover suave entre pastas e largura correta dos diálogos (2026-11-08) — CANDIDATA

- **Correção funcional:** R50 não havia implementado a troca por hover; R51 passa a fazê-lo no `PopupCoordinator`: uma pasta abre por clique; com ela aberta, 150 ms sobre outra pasta fecha/revela de modo serializado, mantendo um único popup. Clique na mesma pasta fecha; clique em outra alterna de imediato. Cancelamento por saída do mouse e encerramento externo preservado.
- **Desempenho:** reaproveita o `PopupAnimatedContent` e a cerca da R45 (`folderPopupOpening`) para não voltar a engasgar o leque; sem modificação de TaskModelController, FolderFanView ou SNI.
- **Configurações:** removidos overrides de largura/altura de R50 em `ConfigItems.qml`; a edição de pasta usa largura natural maior (56 unidades), respeita janela hospedeira e usa rolagem em telas menores. Diálogo Adicionar dimensiona-se pelo tipo real, sem alças manuais.
- **Estado:** testes offline e empacotamento verificados; validação visual em KDE Plasma 6.8.2 pendente. R49 é o retorno aprovado. Ver `LEIA-ME-R51.md`.

## R50 — formulários de configurações adaptáveis (2026-11-08) — CANDIDATA, KDE PENDENTE

- **Base aprovada R49:** fluidez do leque R45, nitidez 2× R47, categorias do menu R48/R49, remoção do progresso de downloads R49, SNI nativo, scroll, mini-player e lixeira mantidos.
- **7 diálogos revisados:** adicionar item, editar item existente, calendário/relógio, lixeira, player, PunchiMenu e centro de controle. Medem a altura real do conteúdo e respeitam a janela hospedeira; quando a altura não cabe, usam scrollbar vertical interna, mantendo botões de rodapé fora do scroll.
- **Campos estreitos:** rolagem horizontal condicional, sem alças de resize manual nas janelas internas; a janela KCM do KDE segue gerenciada pelo próprio Plasma.
- **Sem mudanças:** lógica de salvamento, rascunhos, KConfig, core TaskManager, tray SNI, animações, ícones e menu Normal. Ver `LEIA-ME-R50.md`.
- **Estado:** testes offline e patch; validar no Plasma real antes de aprovar. R49 é a base de retorno.

## R49 — remoção do progresso dos ícones e hover de categorias (2026-11-08) — TESTE KDE PENDENTE

- **Base aprovada:** R48 teve fluidez do menu confirmada; R47 teve ícones do leque melhorados com fluidez; R45 preserva a proteção pre-popup do TaskManager.
- **Removido completamente:** ponte C++ `DockProgressBridge`, assinaturas/timer D-Bus de progresso, porcentagens, barras/efeitos de downloads nos ícones, bindings de progresso em itens fixados/dinâmicos/tray, WebExtension e host Firefox opcionais e scripts de integração antigos. Ver `LEIA-ME-R49.md`.
- **Preservado:** estados dos aplicativos abertos (inclusive SNI/tray-only), neon, scroll, ícones em 2× do leque, MPRIS/player, lixeira, atalhos Downloads e notificações KDE externas.
- **Menu:** hover 45 → 35ms mantendo a cache de categorias da R48 e o cancelamento por saída do ponteiro.
- **Limpeza opcional:** `scripts-user/remover-integracao-downloads-legada.sh` localiza e remove exclusivamente host/manifesto anteriormente instalados pela Punchi, mediante `--remover` explícito. Nenhuma configuração KDE/Firefox é alterada automaticamente.
- **Situação:** testes offline e empacotamento; compilação e validação visual no Plasma real pendentes. R48 é a base de retorno.

## R47 — nitidez dos ícones do leque (2026-11-08) — VALIDAÇÃO VISUAL PENDENTE

- **Base aprovada R45:** leque sem engasgos percebidos com aplicativos maximizados e todas as funções funcionando. **Não regredir** TaskManager pre-popup hold, scroll, indicadores ou SNI nativo.
- **R46 reprovada visualmente:** usuário confirmou sem diferença perceptível; os ícones no menu continuam muito superiores aos do leque.
- **R47:** `SystemDiscovery` agora fornece `appIcon` KService real para atalhos `.desktop` no leque; `FolderFanView` desenha ícone Kirigami 2× com downscale 0,5 e contrarrotação apenas no próprio ícone, mantendo a posição, tamanho, etiquetas inclinadas, curvas e animação originais. Sem `layer.enabled`/novo cache ou rasterização por quadro.
- **Testar no KDE real:** nitidez no menu/leque para os mesmos atalhos; comparar fluidez, D-BusMenu, scroll, execução e app fixes com R45.
- **Aprovação:** testes offline ≠ homologação visual. Consultar `LEIA-ME-R47.md` e `tests-dev/test-r47.mjs`.

## R46 — qualidade dos ícones do leque (2026-11-07) — TESTE VISUAL PENDENTE

- **Base homologada R45:** usuário confirmou sem engasgos perceptíveis na abertura de leques com janelas maximizadas e funcionamento das demais funções. **Não regredir** a proteção pré-popup do TaskManager nem menus SNI nativos, indicadores, scroll ou comportamento de autostart.
- **Novo defeito visual observado:** ícones de aplicativos do leque aparentam qualidade inferior aos equivalentes do menu nas capturas do KDE; correção **implementada em R46, ainda não aprovada** no Plasma real.
- **Correção:** no `FolderFanView.qml`, mesma renderização Kirigami do menu (`roundToIconSize: false`), `smooth: true` e preferência pela origem `appIcon` quando existir, sem perder `icon`/KIO/KService e fallback.
- **Desempenho:** nenhuma mudança em `TaskModelController`, SNI, popup, curvas, escala ou tempo; testar 15 aberturas com janelas maximizadas antes de homologar.
- **Notas:** ver `LEIA-ME-R46.md` e `tests-dev/test-r46.mjs`.

## R45 — pré-proteção TaskManager e organização de tray (2026-11-07) — CANDIDATA

- **Motivo:** R44 manteve 33/33 aberturas com quadros lentos, mediana 42ms, `task-deferred-events=0`; R43 B sem callbacks apresentou mediana 7ms. O guard da R44 começava tarde ou interceptava os eventos errados.
- **Implementado:** sinal síncrono `folderPopupOpening` antes do diálogo; somente para modo leque, `TaskModelController` desabilita temporariamente os callbacks visuais de apresentação do KDE TasksModel **antes** de mapear popup; recupera dados estruturais, foco, maximização, janelas e wheel após período, sem congelar o TasksModel real ou o tray/SNI. Fail-safe 2200ms; restauração na conclusão e ao fechar popup.
- **Bandeja:** filtro existente de aplicativos iniciados manualmente e exclusão de autostart preservados. Nova orientação integrada em Configurar → Janelas para configurar duplicatas como Sempre ocultas no painel KDE, *manualmente*, conservando acesso no tray expandido. Não altera configuração global.
- **Preservados:** nativo SNI e D-BusMenu, scroll, ícones corretos, pins, processos, KWin, geometria, animação, mídia, downloads e lixeira.
- **Estado:** validação offline; compilação KDE e ganho visual ainda pendentes. Sem aprovação final até teste com janelas maximizadas.

## R44 — sincronização seletiva TaskManager / leque (2026-11-07) — CANDIDATA

- **Origem:** teste R43 A1/B/A2 de 27/25/19 aberturas com 4 entradas tray e 3 janelas maximizadas: mediana do pior intervalo 38/7/37 ms. Usuário confirmou que a fase B ficou visualmente mais leve.
- **Correção:** o TasksModel do KDE permanece vivo; durante a abertura curta do leque a Punchi agrupa notificações do modelo e não reconstrói todos os ícones nem o histórico de scroll. Publica atualização única 90 ms após o fim do movimento, com prioridades de estrutura, identidade, foco e minimização preservadas.
- **Filtro:** notificações somente de geometria/metadados não acionam recálculo global; eventos relevantes continuam disparando o indicador correto fora da abertura.
- **Preservados:** R41 tray incremental, menus D-Bus reais, permanência SNI, filtro autostart, ícones, pins, scroll, player, downloads, lixeira e curva/tempo da animação.
- **Estado:** implementação e testes offline; build C++ e desempenho real Plasma 6.8.2 ainda pendentes. Não homologar antes de testar aberturas com janelas maximizadas e validar funcionalidades.

## R42 — Diagnóstico A/B SNI reversível (2026-11-07)

- Base R41, sem perda de recursos; observar SNI Punchi on/off em tempo real via arquivo runtime e QFileSystemWatcher, sem polling.
- Ao suspender: desconectar apenas inscrições D-Bus da Punchi; parar timers; invalidar respostas antigas por epoch; congelar cache (não desativar o tray KDE).
- Ao reativar: nova leitura assíncrona e nova observação de janelas como baseline, preservando a regra de autostart e as funcionalidades aprovadas.
- Log do leque com modo `tray-observation`; scripts de controle/diagnóstico e teste offline novo. A correção do engasgo permanece a validar no KDE real.

# Alterações atuais — Punchi Dock Remastered REA R41

| Recurso | Estado | Evidência / observação |
|---|---|---|
| Discord — permanência após X | **Aprovado pelo usuário na R32/R33** | Ícone permanece após fechar a janela, tray real associado ao aplicativo |
| Discord — ícone correto | **Aprovado pelo usuário na R33** | Usuário confirmou que a imagem correta agora aparece ao fechar a janela |
| Telegram — permanência após X | **Aprovado pelo usuário desde R31** | Preservado no código da R34 |
| ZapZap, qBittorrent e Steam | **Referências aprovadas pelo usuário** | Integração SNI, menu real e clique esquerdo preservados |
| Leque — pequenos engasgos | **R40.1 aprovada sem maximização; R41 candidata para maximização** | Engasgos persistiram nas R40.1/R40.2/R40.3 com múltiplas janelas maximizadas; R41 reduz custo da ponte TaskManager-SNI, ainda não homologada |
| Leque — otimização de composição | **Implementada em R34, não validada visualmente** | Transparência global aplicada por delegado; curva, tempos e escala externa preservados |
| Integração tray — observação de janela | **Otimizador R34, não validado visualmente** | Observação seletiva por roles TaskManager reais e lote de 50ms; não mais por toda revisão visual |
| Diagnóstico de intervalos de quadros | **Adicionado na R34** | Um resumo por fechamento de leque no journal, sem alterar configurações |
| Início automático sem interação | **Regra preservada, rever em teste** | Nenhum ícone dinâmico só por SNI da sessão inicial |
| Scroll, player, downloads, lixeira e pastas | **Funcionalidade preservada** | Leque alterado apenas na composição; verificar regressões visuais |
| Popup de downloads KDE duplicado | **Pendente** | Não alterar serviços KDE globais |
| Compilação C++ / teste Wayland R41 | **Pendente** | Compilação R40.1 confirmada pelo usuário; R41 requer recompilação nativa no openSUSE e teste de maximização |

## R35 — análise do diagnóstico real da R34

- 24 aberturas medidas; 22 com 0 entradas observadas de tray, uma com 1 e outra com 2.
- Uma amostra sem entradas teve pior intervalo de 31ms; com 1 entrada houve 100ms, e com 2 houve 410ms. Isso indica **correlação**, mas não demonstra que o tray causou o engasgo. Contagem R34 é feita ao FECHAR o popup.
- Cache dos resultados de SNI/associação por versão de estado; evita reexecutar buscas KService no caminho de leituras de propriedades QML.
- Nova sonda: contagem no início e fim da abertura, número de revisões de tray durante o movimento e alertas quando uma rotina síncrona C++ excede 20ms.
- Não alterados: curvas, tempos, ícone Discord, permanência, menus, scroll, player, downloads e regras de autostart.

**Revisão R36: candidata de desempenho e diagnóstico, não homologada.**


## R36 — novo diagnóstico e intervenção limitada

- Relatório R35 apresentou eventos de 337 ms mesmo com zero entradas de tray, e 139–143 ms com três SNIs. Não há prova de que todo engasgo seja gerado por SNI.
- Medições síncronas: `finishRefresh` até 138 ms; `observeWindowTasks` até 140 ms. Os tempos incluem atualização de sinais/QML, não apenas lógica nativa.
- R36 não altera geometria, curva nem duração da abertura. Enquanto o leque está abrindo, agrupa atualizações de SNI e conserva **todos** os snapshots distintos de janelas para processamento posterior, na ordem.
- Atualizações de janela que não alteram `entries`/`observedEntries` não disparam emissão desnecessária de `entriesChanged`. Cache de nomes oficiais KDE acrescentado.
- Diagnóstico reporta separadamente trabalho total e custo da emissão de sinais, além do atraso até a primeira troca de quadro.
- Um limite de segurança libera trabalho pendente em caso de animação travada.
- Discord (ícone correto e permanência), Telegram, ZapZap, qBittorrent e Steam preservados; não há nomes de aplicativos hardcoded no caminho novo.
- **Ainda não compilado no KDE**, pois o container não tem ECM; esta revisão não é homologada.

## REA R37 — separação de sinais e estabilidade do leque (CANDIDATA)
- Com base em `punchi-leque-r36.txt`: sinais da ponte levam até 192/160ms; aberturas podem apresentar 277ms com troca SNI e 204ms sem tray. Defeito de fluidez ainda NÃO aprovado.
- Separadas notificações QML de notifiers registrados, observados e dinâmicos.
- O modelo de aplicativos observados não recebe mais alterações mutáveis de metadados SNI.
- Registro QML de menu nativo reduzido a IDs, serviço e caminho de menu, sem perder o registro interno completo.
- Preservadas correções de Discord/Telegram, Wayland, menus, scroll e filtro de autostart.
- Testes offline não comprovam melhoria visual; exige homologação no KDE real.

## R38 — candidata (não homologada)

- Dados R37: até 123 ms com duas entradas; notificações QML registradas até 115 ms e dinâmicas até 91 ms, inclusive aberturas sem revisão de SNI.
- Cache de identidade de apps fixados e presença de SNI; `registeredDesktopIds` separado da notificação de menu.
- Um único resultado SNI para indicador e `trayOnlyExecution` do item. Sem mudanças na animação, curva ou duração.
- Discord/Telegram e demais tray aprovados preservados no código; real Wayland ainda pendente.

## R39 — candidata após diagnóstico real da R38

- R38: `first-swap-delay-ms` até 198 ms com 4 entradas SNI, quadro interno geralmente 6–24 ms; uma amostra sem tray com 195 ms. Essas métricas não comprovam a causa.
- Corrigida medição: agora separa primeiro swap visível de primeiro swap animado e momento do início da animação.
- Evita `visualParent=null/restore` durante o curto período de abertura do leque, preservando associação inicial e aplicando um ajuste final, se necessário.
- Elimina `mapToItem` inútil quando a cauda da janela está desabilitada no layout fan.
- Ícone Discord e permanência no tray permanecem aprovados conforme R33; desempenho R39 ainda precisa ser testado na sessão Wayland real.

## R40 — arquitetura incremental e sincronização do leque (CANDIDATA)

- R39 registrou atrasos iniciais de animação com 4 SNIs (muitos entre 130 e 146 ms) apesar de o primeiro quadro visível aparecer bem antes. A causa final ainda não está comprovada.
- Substituído polling completo de 9 s por eventos D-Bus com lote de 60 ms e verificação periódica de 120 s; processamento de apenas serviços que mudaram.
- Novos metadados de menu são atualizados por serviço conhecido, sem varredura geral. Falhas temporárias não removem imediatamente identidades anteriores.
- O fan possui liberação por quadro renderizado, preservando o mecanismo Window.frameSwapped e o fallback. Registro de `reveal-release-source` identifica qual mecanismo iniciou cada abertura.
- Testes sintéticos de até 128 serviços passaram; compilação C++/KDE Wayland e fluidez real AINDA PENDENTES.
- Aplicativos aprovados, autostart, menus e ícones mantidos no código; revalidar no Plasma real.


## R40.1 — hotfix de compilação (candidata)

- Corrigido `const auto bus` para `auto bus` no construtor de `TrayWindowBridge` (`traywindowbridge.cpp`), eliminando a incompatibilidade com `QDBusConnection::connect` exposta pelo GCC 16.2.1 no log do usuário.
- Sem alterações funcionais de SNI, leque, scroll, menus, ícones, downloads ou player.
- Testes offline e verificação de patch/arquivos: passam. **Compilação no KDE real ainda pendente.**


## R41 — integração nativa incremental (candidata, 07/11/2026)

- Base escolhida: **R40.1 aprovada no KDE real**. R40.2 (adiamento global do TaskManager) e R40.3 (otimização de blur não conclusiva) **não foram incorporadas**.
- `TrayIdentityModel`, implementado em C++ com `QAbstractListModel`: lista somente de IDs de apps efetivamente observados, com `beginInsertRows`/`beginRemoveRows` no lugar de resets completos. A ponte QML do scroll consulta o cache nativo sob demanda, sem ligar sua propriedade a um QVariantList reconstruído. O modelo de itens visuais tray permanece com seu filtro comprovado de pins e serviços.
- `TaskModelController.qml`: uma passagem de TaskManager para observações conjuntas de janelas, serviços e maximizados; maximização isolada é processada sem buscar KService nem remodelar SNIs. Histórico do scroll deixa de ser recalculado por alterações alheias a foco.
- `main.qml`: assinaturas distintas de identidade de janelas e de apps maximizados. JobView/browser continua recebendo atualizações da observação de janelas. Telemetria passiva indica quantidade de janelas maximizadas no início de cada abertura.
- Permanecem **inalterados**: menus SNI reais via DBusMenu, clique esquerdo Activate, regras de interação pós-autostart, verificação de IDs de apps, pin fixo, contexto, tray-only, ritmo do leque, efeitos visuais, mini player, lixeira, downloads, atalhos e geometria Wayland.
- 11 testes offline de regressão; **desempenho em janelas maximizadas e build C++ precisam de teste real**. Não afirmar que o problema do KWin foi resolvido até haver medição.


## R43 (2026-11-07) — Em validação
Diagnóstico A/B independente do TaskManager visual com watchdog de 180s; base R42, funcionalidades de tray e leque preservadas, teste KDE pendente.


## R48 — responsividade do menu Normal (08/11/2026, candidata)

- R47: usuário confirmou qualidade dos ícones do leque melhorada, animação fluida e funcionalidades preservadas. R47 é a referência aprovada para retorno.
- Após essa aprovação, surgiu somente um novo defeito: leve lentidão ao passar o mouse pelas categorias na barra lateral do menu Normal.
- `PunchiMenuNormal.qml`: hover de 85 para 45 ms, mantendo cancelamento ao sair e clique imediato.
- Novo cache `cachedCategoryRows` da lista de aplicativos normalizada/filtrada, compartilhado com cache KService existente e invalidado em mudanças de catálogo, aplicativos ocultos, opção de exibição ou nova sessão do menu.
- `publishCategoryRows` impede recriação da grade quando a categoria/modelo não mudou; categoria All normalizada só uma vez na abertura e atualização correta da busca em mudanças de catálogo.
- Arquivos críticos R45/R47 (TaskManager, System Tray, leque, fonte e renderização dos ícones, menus nativos, scroll) preservados byte a byte.
- **Status:** teste offline concluído; compilação Plasma e fluidez do hover aguardam validação visual do usuário.

## R53 — trava temporária de redimensionamento da janela principal (CANDIDATA)

- Origem: R52 não impedia que a janela principal fosse reduzida a um tamanho inferior ao editor "Configurar pasta" aberto, cortando campos e gerando rolagem horizontal excessiva.
- Introduzidos limites `Window.minimumWidth`/`Window.minimumHeight` calculados em tempo real pela dimensão **natural** do editor e pelo espaço do KCM, com teto pela área útil do monitor.
- Aplicado aos sete diálogos internos de configuração; bindings ativos somente enquanto um deles estiver visível, restaurando os mínimos anteriores ao fechar.
- O tamanho natural não deriva da geometria já truncada; proteção contra captura recursiva dos mínimos; posicionamento não negativo e rolagem em telas compactas.
- Não alterados: pasta R51 por hover, leque R45, ícones R47, menu R49, SNI, indicadores, scroll, dados e persistência.
- Status: testes offline e verificação de patch/arquivos, aguardando compilação/validação real no KDE 6.8.2.

## R54 — dimensionamento de configuração alinhado ao KDE Plasma 6 (CANDIDATA)

- A R53 foi recusada no teste visual: quando a janela principal diminuía, o formulário Configurar pasta criava rolagem horizontal e cortava campos; a alteração do `Window.minimumWidth/minimumHeight` não solucionava a causa.
- Removido o bloqueio de tamanho mínimo do host KCM; os sete diálogos agora respeitam a largura atual do viewport através de `kdePreferredWidth` e `contentWidth: availableWidth`, com rolagem apenas vertical quando a altura for insuficiente.
- `ItemEditorPanel` e `ItemActionEditor` não impõem largura mínima global; títulos e descrições da lista se adaptam com elisão. Botões de rodapé permanecem disponíveis.
- `KCM.SimpleKCM` e componentes Kirigami/Qt Controls continuam os mesmos, preservando o estilo nativo e todos os IDs/ações; R51 hover, R45 TaskManager, R47 ícones e R49 menu/SNI preservados.
- **Status:** testes offline concluídos; exige compilação/validação no KDE 6.8.2 do usuário. Ver `LEIA-ME-R54.md`.


## R56.1 — correção localizada de erros QML (aguardando homologação)

Ver LEIA-ME-R56.1.md. Corrigidos GridLayout.spacing, import Kirigami do TrashDialog e seletor legado do calendário. Sem alterar o runtime do leque.


## R58 — CANDIDATA (2026-11-08)

Página Itens reconstruída com prévia horizontal interativa; duplicações removidas, drag-and-drop com commit ao soltar, duplo clique para configurar, controles +/− e alternativas de teclado. Testes offline em TESTES-R58.txt; aguardando teste no KDE real.

### R58.1 — Janela de configurações maximizada (candidata; 2026-11-08)
- Novo `ConfigMaximizedWindowGuard.qml` não visual observa apenas a janela KCM hospedeira, solicita `showMaximized()` se restaurada, em cada uma das sete categorias do Punchi.
- Não maximiza diálogos filhos, não mexe em flags/limites da janela, não interfere no fechamento, minimização ou KWin global.
- Runtime não alterado. Revisão offline; validar no Wayland real. Ver `LEIA-ME-R58.1.md`.


## R59 — Editor da dock no padrão aprovado (candidata)

- Fundo e bordas da prévia usam tema KDE com gradiente discreto.
- Ícones distribuídos conforme a largura e contagem dos itens; overflow mantém rolagem.
- Removidos botão configurar extra e rótulo de seleção; instrução inferior mudou para "Clique e arraste para reordenar".
- Controles Adicionar/Remover próximos da prévia.
- Traduções pt-BR na página Itens; guard contra remoção do PunchiMenu também no fluxo de dados.
- Margens internas dos dois editores de item alinhadas a Kirigami.Units.
- Status: **candidata, aguardando teste real**; restante da configuração, runtime e KCM preservados.
