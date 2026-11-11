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

## 2026-11-08 — R61 (candidata): arraste de vários itens e escolha visual de aplicativos

- Correção real da seleção múltipla: Qt.RightButton, estado de múltiplos índices e movimentação coletiva determinística, mantendo seleção, ordem relativa, animações e persistência por Aplicar/Cancelar.
- Catálogo visual dos lançadores KDE: pesquisa, filtros, seleção múltipla; adicionar à dock e a pastas manuais a partir dos registros `KApplicationTrader` existentes. Comandos personalizados continuam acessíveis.
- Testes offline e documentação completos; aguardando avaliação na máquina KDE do usuário.

## 2026-11-08 — R60 (candidata): central acompanha cores e estilo nativos do KDE

- A prévia visual da página Itens deixa de escurecer e tingir cores por multiplicadores absolutos e passa a interpolar cores reais `Kirigami.Theme.View`, incluindo fundo, texto e destaque.
- Janelas KCM, botões Qt Controls e diálogos continuam nativos; nenhuma regra de configuração ou runtime da dock foi alterada.
- Testes offline adicionados; homologação visual no Plasma 6.8.2 pendente.

## 2026-11-08 — R57.1 (candidata): preview de pasta com conteúdo real

- R57 mostrava apenas quatro placeholders em `FolderLayoutPreview.qml`, independentemente da pasta.
- R57.1 usa os valores `apps[].name` e `apps[].icon` do item escolhido; lista de conteúdo no inspetor permite conferir os itens antes de abrir Configurar pasta.
- Não altera a dock em execução, o conteúdo salvo nem o formato do JSON; homologação visual pendente.

## R57 — reconstrução incremental da configuração (candidata em 08/11/2026)

**Estado:** implementação e testes offline concluídos, sem homologação no Plasma real. Ponto de partida: R56.1.

**Aprovado para teste, ainda não aprovado como padrão estável:** inspetor contextual Itens, pesquisa com índices preservados, edição rápida e reversível do nome, seletor e prévia do tipo de pasta, reordenação animada via `ListModel.move`, ajuda expansível, layout estreito do editor e prévia animada de ícones em Geral. Preservados `ConfigModel`, `main.xml`, `cfg_dockItemsJson`, sete diálogos e arquivos de runtime da dock.

**Pendente:** executar e homologar em KDE Plasma 6.8.2/Wayland; reconstruir progressivamente demais páginas e diálogos, validar escalas e movimento reduzido, evitar regressões de R55/R56. O teste antigo R56 sobre o painel de nota vazio foi substituído pelo novo requisito de inspetor, não regredido acidentalmente.

## R56 — 2026-11-08: arquitetura KDE de configurações (candidata)

Base R54 para corrigir regressão R55 de página branca e limitar popups à janela KDE, com KCM.AbstractKCM, responsividade da lista e overlay QtQuick Controls.

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

## R45 — proteção TaskManager desde o clique e tray visível configurável (2026-11-07)

A R44 passou nos testes offline mas log R44 de 33 aberturas com três janelas maximizadas mostrou mediana de pior intervalo 42ms e zero callbacks adiados; a proteção só iniciava após popup mapeado. A R45 desconecta previamente os callbacks QML do TaskManager exclusivamente na Punchi para abertura no modo leque, reconcilia as informações após a animação e possui fail-safe automático. O comportamento já aprovado de não criar entradas dinâmicas por apps autostart permanece. Incluídas instruções de uso das opções **Sempre oculto** do System Tray KDE para apps lançados manualmente, sem interferir na bandeja real. Compilação Qt/KF6 e desempenho ainda pendentes.

## R44 — mitigação permanente orientada pelo A/B R43 (2026-11-07)

- Dados de R43 fornecidos pelo usuário: A1 Task ON 27/27 aberturas com intervalo >25 ms, mediana do pior quadro 38 ms; B Task OFF apenas 1/25, mediana 7 ms; A2 restaurado 19/19, mediana 37 ms. Usuário percebeu maior fluidez em B.
- Não desliga permanentemente o TaskManager ou SNI. QML agrupa eventos do TasksModel apenas enquanto o `fanRevealCritical` abre a pasta, atualizando estado após o período crítico; sem alteração de drivers/KWin.
- Filtro de roles e publicação visual seletiva impede revisões globais por eventos que não alteram os ícones. Eventos de estrutura, foco, maximização e roda do mouse são conservados.
- Log R44 informa eventos adiados e reconciliações; testes offline R31–R44 executados. Desempenho e compilação nativa ainda a comprovar no openSUSE.

## R42 — Diagnóstico A/B SNI reversível (2026-11-07)

- Base R41, sem perda de recursos; observar SNI Punchi on/off em tempo real via arquivo runtime e QFileSystemWatcher, sem polling.
- Ao suspender: desconectar apenas inscrições D-Bus da Punchi; parar timers; invalidar respostas antigas por epoch; congelar cache (não desativar o tray KDE).
- Ao reativar: nova leitura assíncrona e nova observação de janelas como baseline, preservando a regra de autostart e as funcionalidades aprovadas.
- Log do leque com modo `tray-observation`; scripts de controle/diagnóstico e teste offline novo. A correção do engasgo permanece a validar no KDE real.

# Histórico consolidado — R21 → R23

- **R21 (base):** pacote enxuto, popup informativo acima da dock, janela de menu para SNI experimental, regra de navegador maximizado para limpar download concluído, otimização de gravação da reordenação. A R21 ainda exibia problemas de tray, layout da configuração, mosaico das pastas e tamanho do popup.
- **R22 (esta revisão):** substituição do host de menu QtQuick.Controls.Menu por `QtQuick.Window` transitória com respostas imediatas e diagnóstico; popup mini player apenas metadata com largura dependente do texto e imagem de fundo contida; pastas grade interna recortada e borda elevada; opção ciano elétrico durante download; transição mais lenta da lixeira; reorganização das opções de pasta e atualização de catálogos de idiomas; correção do pacote PipeWire e configuração CMake para instaladores sem testes. Testes estáticos/regressão JavaScript não equivalem a homologação Wayland.

- **R23 (esta revisão):** resolveu a falsa seleção da rota SNI para apps fechados; adiou a solicitação do menu até a liberação do botão direito e utilizou o popup nativo Plasma ancorado via visualParent em vez de x/y absoluto. Implementou equivalência restrita via serviço KDE/arquivo `.desktop` entre lançador fixado e tarefa, para agrupar janelas sem criar entrada duplicada, incluindo SNI; centralizou cartão mini player em relação ao item inteiro. Ainda requer testes reais no Plasma KDE Wayland para confirmar ZapZap/qBittorrent, Konsole e posicionamento. Nenhuma alteração no download/lixeira/scroll.

**Decisão de trabalho:** novas modificações depois desta entrega só com autorização explícita “pode fazer as correções”.

- **R24:** integração voluntária e reversível com o arquivo Qt de preferências do VLC (sem notificações globais do KDE), remoção da seta sobreposta nos mosaicos de pastas e reforço de aliases KDE dos aplicativos fixados para evitar janelas separadas. Catálogos pt_BR/es/de atualizados. Menu nativo ZapZap segue pendente de diagnóstico e compilação real ainda requer KDE.


## R25 — aguardando homologação no KDE Plasma Wayland
Correção de seleção de identidade SNI, suporte a namespace org.freedesktop, atualizações NewMenu e requisição assíncrona tolerante a perda transitória de foco. Logs de D-BusMenu e diagnóstico somente leitura. Corrigida leitura de progresso 100% no mesmo sinal progress-visible=false; não infere sucesso de cancelamentos. Incluído atalho para as Configurações do KDE para ocultar popups de progresso por escolha explícita do usuário. Não homologados em ZapZap/qBittorrent nem no Firefox real; ausência de ECM/Qt/KF6 impede compilação neste ambiente.

## R26 (2026-11-07) — Pré-validação
Integração de downloads Firefox desacoplada da apresentação de notificações KDE, com WebExtension opcional, host por usuário e testes de protocolo. Instalação completa da extensão no Firefox comum ainda exige assinatura; temporária para homologação. System Tray ZapZap/qBittorrent permanece pendente.

## R27 — homologação parcial (2026-11-07)
- Usuário compilou R27 com sucesso no openSUSE (CMake e C++ em 100%).
- Konsole passou no teste real: um único ícone fixado sem duplicar ao abrir.
- ZapZap passou a exibir opções nativas, incluindo Sair, mas com defeito de altura/clipping do menu em alguns cliques.
- Duplicação de notificações/download do KDE permaneceu.

## R28 — regra geral por identidade e UI de menu (2026-11-07)
- Mesmo critério aplicado aos ícones fixados, tarefas dinâmicas e notifiers do tray, usando identidade canônica KService comprovada e interpretação segura dos comandos.
- Suporte de correspondência a wrappers Flatpak/gtk-launch, sem heurísticas por título ou ícone.
- Popup de tray só abre quando há ações reais ou fallback por timeout, com dimensões calculadas antes da apresentação; navegação entre submenus reinicia geometria.
- Base C++ e funções de scroll, lixeira, mini player e downloads preservadas. Revisão experimental aguardando compilação R28 e homologação Wayland.

## REA R29 — 07/11/2026 — implementação candidata

- Ponte SNI ampliada para equivalência entre IDs de tarefas e serviços KService, com tratamento determinístico de aliases e exclusão de duplicações com janelas visíveis.
- Registro completo de SNI exposto separadamente para recuperar menus dos ícones fixados; o modelo dinâmico continua filtrado por interação/janela observada.
- Cliques explícitos na dock marcam interação com aplicativos; registro de notifier no login não marca interação.
- Menus de tray agora nunca apresentam ações substitutas; a ponte solicita apenas DBusMenu exportado ou ContextMenu do próprio SNI.
- Filtro **opcional** reversível de popups de notificações Firefox, sem alterar jobs globais; popup de progresso do KDE permanece pendente até teste real.
- Nenhuma mudança no scroll, mini player, lixeira, backend de downloads, integração VLC ou demais controles.
- Qt/ECM e sessão Wayland indisponíveis na máquina de empacotamento; compilação e homologação pendentes.

## R30 — 07/11/2026 — permanência SNI após ocultar janela

**Motivo:** vídeo do usuário mostrou Telegram e Discord desaparecendo da dock ao fechar a janela na R29. Aplicativos com SNI válido deverão seguir o mesmo padrão aprovado em ZapZap, qBittorrent e Steam.

**Alterado:** `src/traywindowbridge.{cpp,h}` observa alias/KService/PID das janelas, resolve PID do SNI de forma assíncrona com D-Bus e retém vínculo verificado após fechar a janela. Evita pareamento por PID compartilhado, item duplicado e promotion de serviços de autostart. `TaskModelController.qml` envia snapshots reais de janela (incluindo AppPid). `main.qml` conecta essa nova API e preserva a lista prévia do KDE Jobs/Firefox.

**Verificado:** testes offline QML executados no Node, validação estática do código C++ e `bash -n`. **Não compilado/homologado no Plasma:** faltam ECM/KF6 nesta máquina; testar o pacote no openSUSE e não declarar o defeito resolvido antes de conferir Telegram/Discord, ZapZap/qBittorrent, Steam, autostart e scroll. Não modificados: scripts de instalação, preferências do KDE, progresso de downloads, mini player, pastas, lixeira.

## R31 — 07/11/2026 — NOVA CANDIDATA (não homologada)
- Usuário confirmou falha da R30 em Telegram e Discord após fechar pelo X;
  ZapZap, qBittorrent e Steam permanecem padrão aprovado.
- Investigada a especificação SNI e o código `xembed-sni-proxy` do KDE: Id e
  WindowId vêm da janela XEmbed; PID de D-Bus pode ser o do proxy.
- Corrigida observação de aplicativo com janela ativa que fecha para o tray,
  mesmo quando a janela estava presente no snapshot inicial.
- Fallback genérico assíncrono para WM_CLASS/_NET_WM_PID via xprop, sem nomes
  hardcoded de aplicativos e sem bloquear plasmashell.
- Associação secundária por AppName de tarefa observada; evita colisões entre
  apps distintos e não admite SNI de inicialização como item dinâmico.
- Preservadas rotas originais de KService, menus nativos, scroll, downloads.
- **Estado:** apenas testes offline; não compilado/homologado no KDE real.
- Arquivos de diagnóstico e instruções em LEIA-ME-R31.md.

## R32 — 07/11/2026 — Discord: identificador SNI gerado (candidata)
- **Confirmação do usuário:** Telegram corrigido com R31; Discord continua desaparecendo ao fechar a janela.
- **Diagnóstico fornecido:** janela `com.discordapp.discord` registrada e fechada; SNI ainda vivo `discord_status_icon_1`, porém sem `DesktopEntry` e com `WindowId=0`. R31 não tinha como extrair WM_CLASS da janela inexistente e não comparava o sufixo gerado do Id com o nome estável do aplicativo.
- **Alteração específica e genérica:** extrair prefixo de ID inteiramente conforme o formato `<app>_status_icon_<N>` ou `<app>_tray_icon_<N>` (também separador hífen); corresponder somente a aplicativo que o usuário abriu/ativou na sessão, por `AppName` ou último segmento de AppId qualificado. Manter recusa de múltiplas identidades distintas, filtro de autostart e verificação de SNI presente.
- Para ícones fixados, o mesmo formato de ID permite localizar SNI de app já iniciado sem aumentar a lista dinâmica. Não foi introduzida regra dedicada ao Discord.
- Log de fechamento de janela agora registra somente os **IDs técnicos** dos SNIs associados, para facilitar diagnóstico posterior; conteúdo de mensagens/janelas não é lido nem registrado.
- Preservados Telegram R31, ZapZap, qBittorrent, Steam e todos os demais subsistemas sem alterações. Mantido o fluxo de menu e restauração da instância existente.
- **Validação:** testes offline R31/R32 e integridade ZIP; compilação KDE e uso real ainda pendentes. Usuário precisa verificar o Discord antes de aprovar.

## R33 — 07/11/2026 — fluidez do leque e identidade de ícone (candidata)

- Usuário confirmou **Discord permanece na dock após X** na R32, mas com imagem genérica; Telegram segue funcional. Análise do diagnóstico R32 confirmou `discord_status_icon_1` associado a `com.discordapp.discord`.
- Usuário relatou engasgo leve **em todas as aberturas do leque**; vídeo mostra aberturas repetidas, mas não mede o custo da thread QML nem demonstra causa específica.
- `FolderFanView.qml`: coalescer múltiplas atualizações `contentY`, evitar reposicionamento redundante, não animar simultaneamente `ListView.move` durante reveal, manter itens visíveis no cache e reutilizar distância geométrica por delegado. Curva e duração originais preservadas.
- `main.qml`: comparar snapshots KDE antes de reenviar dados inalterados ao tray e progresso, sem perder mudanças de janela real.
- `traywindowbridge.cpp`: resolver ícone oficial por identidade KDE case-insensitive exata e guardar cache para evitar busca repetida; fallback no tema e exportação SNI mantido. Sem tratamento exclusivo para Discord.
- Testes de fonte e lógica R31/R32/R33 passaram; compilação KF6 e teste da fluidez real pendentes por indisponibilidade do ECM. Revisão **não homologada**.


## R34 — 7 de novembro de 2026

- Usuário validou oficialmente a imagem correta do Discord na R33, além da permanência já aprovada. Registrar como referência funcional, sem modificar a lógica de associação SNI.
- Usuário repetiu teste envolvendo todos os aplicativos com tray e confirmou que a microtravada do leque persiste em cada abertura. R33 não resolve o defeito de fluidez.
- Otimização experimental do leque: transferência da opacidade externa para o delegado individual; mantém a mesma função de transparência, a transformação de escala externa e a animação de curvatura já existente. Reduz uma etapa de transparência aplicada à superfície inteira, sem alterar tempo da animação.
- TaskModelController filtra atualizações de interesse real para ponte de tray/progresso e consolida observações pendentes no temporizador de refresh já existente; visualRevision continua atualizando indicadores.
- Um resumo do intervalo de quadros (`frameSwapped`) é emitido após cada fechamento de popup de leque e pode ser consultado com `scripts-user/diagnosticar-leque-r34.sh`. Sem rastreamento de conteúdo pessoal.
- Testes Node regressivos R31-R34 e bash -n aprovados; Qt/KF6 e fluidez real ainda pendentes. R34 permanece candidata até confirmação do usuário.


## R35 — 07/11/2026 — cache SNI e diagnóstico de travadas

- Diagnóstico R34 mostrou intervalos típicos de 6ms quando `tray-entries=0`, mas casos de 100ms com 1 entrada e 410ms com 2. Uma ocorrência isolada de 31ms não tinha entrada; correlação não é prova de causa.
- `tray-entries` era medido no fechamento, não no exato instante do pico.
- `TrayWindowBridge` guarda as listas derivadas `entries`/`observedEntries` e só invalida quando janela/SNI/interação realmente muda. `canonicalDesktopService` evita pesquisa repetitiva por identidade KDE no mesmo processo, com limite de cache.
- Medições agregadas R35 incluem contagem no início, revisões durante o leque e duração de rotinas síncronas C++ se maiores que 20ms. Não loga conteúdos de janelas.
- Ícone Discord correto e permanência aprovada preservados; não mudou animação, clique/menus, player, scroll, downloads, popup.
- Apenas testes offline; a confirmação de fluidez depende da sessão KDE real.


## R36 — 07/11/2026 — proteção do reveal e controle do custo do tray

- Diagnóstico enviado da R35: com 0 entradas houve amostra de 337 ms; com três entradas houve 139/143/134 ms, enquanto `finishRefresh`/`observeWindowTasks` consumiram até 138/140 ms. Não é causalidade comprovada.
- Durante **somente a abertura do leque**, adia publicação de atualizações SNI e o processamento de snapshots TaskManager; preserva todos os snapshots distintos e os reproduz em ordem ao fim.
- Novo cache do nome oficial do aplicativo, além de cache de ícones e serviços existentes; eliminação de sinais `entriesChanged` para modificações de janela que não mudam os modelos SNI.
- `QTimer` libera a proteção mesmo em popup sem finalização de animação (falha de segurança de 4 segundos).
- Nova coleta `scripts-user/diagnosticar-leque-r36.sh` com custos sinal/total, frame pacing e atraso até primeira apresentação.
- **R36 candidata**, passou verificações offline R31–R36 e sintaxe dos scripts; não compilada no Plasma real. Preservação dos itens aprovados é objetivo do patch, ainda sujeita a teste de regressão.

## R37 — 07/11/2026 — CANDIDATA (não homologada)
- Após medição R36 com até 194ms em callbacks `observeWindowTasks`, 160ms em `finishRefresh` e quadros de 277ms/204ms, isoladas as notificações QML da ponte de tray por modelo afetado.
- `observedEntries` fornece somente desktops únicos e estáveis ao TaskModel; `registeredEntries` fornece somente identidade de SNI/menu ao QML; `entries` continua alimentando ícones dinâmicos.
- Recalcula e publica apenas modelos efetivamente alterados; nenhuma regra por nome, alteração de geometria, duração de animação ou serviço D-Bus nativo.
- Testes offline válidos, compilação KF6 e fluidez no KDE/Wayland dependem da máquina do usuário. Não marcar o defeito do leque como resolvido antes do teste real.

## R38 — 07/11/2026 — candidata

- Diagnóstico real R37 recebido: até 123 ms de frame interval com duas entradas de tray, `registered-ms` até 115ms e `dynamic-ms` até 91ms.
- Separada a identidade dos notifiers do caminho do menu nativo; cache positivo/negativo da associação do KDE no C++, e memoização de identidade no QML.
- Delegado fixado compartilha associação entre indicador e presença no tray. Sem alterações de animação do leque, scroll, downloads ou menús nativos.
- Testes offline R31–R38 executados; ainda falta compilação KDE/Wayland e confirmação da fluidez.

## R39 — 2026-11-07 — isolamento do atraso inicial do leque (candidata)
- Evidência: diagnóstico R38 registra atrasos rotulados `first-swap-delay-ms` entre 107–198ms com 3–4 entradas; sem alterações SNI durante as amostras. A métrica anterior ignorava o primeiro swap enquanto openingPending=true.
- Alteração localizada: guarda de reancoragem nativa `visualParent` apenas durante o opening do fan; janela recém-criada recebe âncora normal e o reposicionamento final é aplicado depois.
- Sem custo de mapa de coordenadas da cauda para fan sem cauda.
- Telemetria desambigua primeiro quadro apresentado, início do reveal e primeiro quadro animado; inclui contadores de reposicionamento.
- Sem alterações de identidade SNI, clique, menus nativos, ícones, autostart, downloads, scroll ou player.
- Validação em Wayland real e compilação KDE ainda pendentes (ECM não instalado no ambiente de empacotamento).

## REA R40 — 2026-11-07 — CANDIDATA, ainda não homologada

Reestruturação conservadora do gerenciamento de SNI: deltas por registro/remoção (60 ms), reconciliação completa de 120 s em lugar de 9 s, NewMenu localizado, retenção do estado anterior em falhas transitórias, proteção do fan durante publicações. `FrameAnimation` complementa `frameSwapped` para destravar o início do leque sem esperar o timeout. Todos os recursos aprovados até R39 permanecem no código. Métricas e compilação Wayland ainda necessárias antes de chamar de correção confirmada.


## R40.1 — correção de build da R40 (não homologada)

- Relatório do openSUSE: compilação interrompida em `src/traywindowbridge.cpp:287` pela declaração constante de `QDBusConnection`. Também falhava em 290/295/298.
- Removido somente o `const` da variável local `bus`; mantida sem alterações a arquitetura por eventos da R40.
- Testes offline e empacotamento validados; aguarda compilação/execução no Plasma real.

## R41 — refatoração de baixo risco do acompanhamento SNI/TaskManager (07/11/2026)

R40.1 foi compilada pelo usuário e aprovada para leque com apps SNI sem maximização. R40.1, R40.2 e R40.3 apresentaram engasgos com múltiplas janelas maximizadas; fechar aplicativos tray restaurava a fluidez, embora isso não demonstre causalidade. R41 **volta ao código-base da R40.1** e altera exclusivamente a superfície de integração de janelas/tray: `TrayIdentityModel` (Qt/C++ com linhas incrementais), observação de janelas em uma passagem, separação de papéis IsMaximized/identidade e redução de recálculos não relacionados a foco no histórico do scroll. O backend SNI, menus reais, configuração de pins, autostart, animação/blur e demais recursos não foram alterados. Testes offline: 11 suites, build real ainda pendente.


## R43 (2026-11-07) — Em validação
Diagnóstico A/B independente do TaskManager visual com watchdog de 180s; base R42, funcionalidades de tray e leque preservadas, teste KDE pendente.


## R46 — uniformização do renderizador Kirigami dos ícones (2026-11-07)

- **Contexto:** R45 aprovada por desempenho e funcionalidade. Capturas de menu e leque mostram diferenças de nitidez, especialmente nos ícones das aplicações do grupo ArtCraft.
- **Causa localizada no código:** menu de aplicações define `roundToIconSize: false`; leque usa `Kirigami.Icon` com arredondamento padrão para tamanhos de tema. A diferença pode reduzir a resolução efetiva quando tamanho não padronizado é utilizado.
- **Patch cirúrgico:** definir `roundToIconSize: false` e `smooth: true` nos ícones de apps do leque e dar preferência a `appIcon` (origem do catálogo KDE, como no menu), preservando fallback `icon` do KIO/KService e `application-x-executable`.
- **Sem mudanças:** código nativo, TaskManager R45, SNI, menus D-Bus, curvas, rotações, tamanhos de itens, geometria, duração, scroll, pins, player e lixeira.
- **Status:** código e testes offline disponíveis; **comparação visual e desempenho no KDE real pendentes**. Reversão por instalador R45 se necessário.


## R47 — KService appIcon efetivo + supersampling 2× + ícone sem inclinação (2026-11-08)

- **Motivação:** R46 foi testada e reprovada pelo usuário: nenhuma melhoria na definição do leque face ao menu. A investigação do código mostrou que `appIcon` não existia nas entradas retornadas pela leitura de pasta, e que `rowContent` aplicava transformações aos ícones e às legendas juntos.
- **Alteração em `src/systemdiscovery.cpp`:** produzir `appIcon` de `KService::icon()` para lançadores `.desktop` válidos, preservando `icon` e fallback de MIME/KIO.
- **Alteração em `FolderFanView.qml`:** um viewport do mesmo tamanho aparente `iconSize`, com um `Kirigami.Icon` requisitado a `2 * iconSize` e desenhado a `scale=0.5`, cancelando o ângulo do `rowLean` somente no ícone; a cápsula e o texto conservam a curvatura macOS.
- **Desempenho:** nenhuma camada GPU extra (`layer.enabled`) ou cache, nenhuma mudança no TaskManager R45, SNI, menu, scroll, geometria ou curva do popup.
- **Validação:** testes offline históricos + R47, patch/ZIP/TAR verificados; a nitidez e fluidez no Plasma 6.8.2 ainda precisam ser homologadas pelo usuário. **R45 continua a referência aprovada.**


## R48 — menu Normal, atraso de hover e cache de categorias (2026-11-08)

- **Base:** R47 aprovada pelo usuário por nitidez do leque, fluidez e funcionamento das demais funções.
- **Solicitação:** menu Normal apresenta leve latência visual ao passar o mouse sobre a coluna lateral das categorias.
- **Alteração:** espera do hover reduzida de 85 para 45 ms; clique permanece instantâneo, e timers continuam cancelados quando o ponteiro sai.
- **Cache:** além da lista KService bruta, manter arrays QML prontos por categoria e não recalcular normalização/ocultação em visitas repetidas. Evitar atualizar modelo quando array é idêntico.
- **Correção de consistência:** invalidação de resultados filtrados em mudanças de catálogo/ocultos; pesquisa ativa recalculada ao atualizar o catálogo, e All não sobrescreve a categoria atualmente selecionada.
- **Proteção:** R45 TaskManager e R47 FolderFanView/SystemDiscovery preservados sem alterações. Nenhum impacto no protocolo SNI ou no KDE global.
- **Status:** candidata; testes reais de resposta ao hover no Plasma pendentes.

## R53 — proteção da janela principal ao editar formulários (08/11/2026)

A captura da R52 mostrou que o diálogo adaptativo ficava cortado ao diminuir a janela externa de Configurações. A R53 passou a controlar o **mínimo da janela hospedeira**, não apenas o tamanho do popup. O mínimo é derivado do conteúdo natural visível dos sete formulários com limite de monitor; ao fechá-los, os mínimos originais voltam. Componentes de leque, TaskManager, tray e troca suave de pastas não foram alterados. Build/visibilidade no KDE real ainda dependem de teste do usuário.

## R54 — revisão do layout das configurações segundo KCM/Kirigami (08/11/2026)

Após gravação de falha da R53, a R54 reverte a manipulação do mínimo da janela externa (`Window.minimumWidth`/`minimumHeight`) e adota uma regra homogênea de largura preferida limitada pelo viewport. Nos sete diálogos, a rolagem horizontal do formulário foi retirada e a vertical permanece condicional; lista e campos encolhem com o espaço disponível, incluindo aplicativos de pastas existentes. O KCM permanece sob gerência do KDE, sem alterar tema, sistema ou dock runtime. **Validação visual pendente.**


## R56.1 (2026-11-08) — hotfix das configurações

Diagnóstico real: ConfigItemsMainView.qml:78 propriedade spacing inexistente em GridLayout; import Kirigami ausente na lixeira; calendarDisplayMode legado indefinido. Mudanças restritas aos arquivos identificados.


## R58 (2026-11-08) — aguardando validação

Reestruturação de ConfigItemsMainView.qml em faixa única com preview de itens, sem DockItemListEditor e sem inspector. Método moveItemToIndex adicionado para preservar seleção/persistência. Veja LEIA-ME-R58.md.

### R58.1 — Janela de configurações maximizada (candidata; 2026-11-08)
- Novo `ConfigMaximizedWindowGuard.qml` não visual observa apenas a janela KCM hospedeira, solicita `showMaximized()` se restaurada, em cada uma das sete categorias do Punchi.
- Não maximiza diálogos filhos, não mexe em flags/limites da janela, não interfere no fechamento, minimização ou KWin global.
- Runtime não alterado. Revisão offline; validar no Wayland real. Ver `LEIA-ME-R58.1.md`.


## R59 — 2026-11-08

Revisão sobre R58.1 após aprovação da prévia: reorganização da página de itens, barra autoajustável, tradução, remoção de controles redundantes e proteção de PunchiMenu. R58.1 permanece para reversão; não homologada no KDE real.
