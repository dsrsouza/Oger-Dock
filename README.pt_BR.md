# Oger Dock

<p align="center">
  <strong>Uma dock personalizável para o KDE Plasma 6</strong>
</p>

<p align="center">
  <img alt="Versão 1.0.0" src="https://img.shields.io/badge/vers%C3%A3o-1.0.0-3b82f6">
  <img alt="KDE Plasma 6" src="https://img.shields.io/badge/KDE_Plasma-6-1d99f3?logo=kde">
  <img alt="Linux" src="https://img.shields.io/badge/plataforma-Linux-555555?logo=linux">
  <img alt="GPL-3.0-or-later" src="https://img.shields.io/badge/licen%C3%A7a-GPL--3.0--or--later-blue">
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.pt_BR.md">Português (Brasil)</a>
</p>

O **Oger Dock** reúne lançadores de aplicativos, janelas abertas, pastas personalizadas, controles multimídia e utilitários do ambiente de trabalho em uma dock fluida e integrada ao **KDE Plasma 6**.

A versão **1.0.0** utiliza como base o comportamento aprovado da R63.7. O principal ambiente de desenvolvimento e testes funcionais foi **openSUSE Tumbleweed com KDE Plasma 6.8.2 e Wayland**. Isso não significa homologação automática para todas as distribuições.

> [!IMPORTANT]
> O repositório está sendo preparado para a publicação inicial do código-fonte. Os comandos abaixo exigem que a árvore completa do projeto seja publicada; somente o README introdutório não é suficiente. Os downloads serão vinculados após a publicação da release.

[Recursos](#recursos) · [Capturas de tela](#capturas-de-tela) · [Instalação](#instalação) · [Compatibilidade](#compatibilidade) · [Testes](#testes-e-qualidade) · [Suporte](#suporte-e-comunidade) · [Licença](#licença)

## Recursos

### Aplicativos e janelas

- **Lançadores personalizáveis:** fixe seus aplicativos favoritos e organize a dock do seu jeito.
- **Alternância por rolagem:** use a roda do mouse para percorrer sequencialmente os aplicativos elegíveis que estão abertos, respeitando a direção e os limites da lista.
- **Indicadores de execução:** identifique visualmente aplicativos abertos e seu estado ativo.
- **Reordenação de itens:** destrave a dock quando quiser reorganizar ícones e outros elementos.

### Integração com a bandeja do sistema

- **Suporte a StatusNotifierItem (SNI):** integração com aplicativos de bandeja compatíveis e seus menus nativos, quando disponibilizados.
- **Reutilização de instâncias:** restaura aplicativos reconhecidos sem abrir processos duplicados desnecessariamente.
- **Respeito à inicialização automática:** aplicativos iniciados junto ao sistema não surgem automaticamente na dock apenas por estarem na bandeja.
- **Scroll protegido:** a navegação com a roda do mouse não promove indevidamente aplicativos exclusivos da bandeja, como o MEGAsync (correção validada na R63.7).
- **Voltar para a tray:** quando disponível, remove uma entrada temporária da dock sem encerrar o aplicativo.

Alguns comportamentos dependem das informações efetivamente expostas pelo gerenciador de tarefas do KDE e pelo aplicativo de terceiros.

### Pastas e organização

- **Pastas em leque:** agrupe aplicativos em uma apresentação animada e organizada.
- **Cores individuais:** escolha nomes e cores para cada pasta ou utilize os padrões de categorias e do tema.
- **Seletor de aplicativos:** encontre programas instalados por busca e categoria, incluindo seleção múltipla para organizar coleções.
- **Arrastar e soltar:** reorganize aplicativos e pastas diretamente pela interface.

### Menu de aplicativos

- **Modos Normal e Reduzido:** selecione a apresentação apropriada para seu espaço de trabalho.
- **Pesquisa e categorias:** encontre aplicativos com rapidez.
- **Controles de sessão:** acesse ações do KDE como desligar, reiniciar e encerrar sessão.

### Multimídia e utilitários

- **Mini player MPRIS:** capa e controles de faixa anterior, reproduzir/pausar e próxima para fontes compatíveis.
- **Informações expansíveis:** título e artista aparecem sem alterar a posição dos controles fixos do player.
- **Lixeira integrada:** abra a lixeira no Dolphin, esvazie seu conteúdo e confirme ações destrutivas.
- **Personalização visual:** indicadores, cores, animações e integração ao estilo do Plasma.
- **Posicionamento:** dock na parte inferior, à esquerda ou à direita da tela; a posição superior não é oferecida.

## Capturas de tela

Adicionaremos capturas reais do Oger Dock em `docs/images/` antes da publicação da galeria visual. Estão previstas imagens da dock horizontal, dock lateral, menu Normal/Reduzido, pastas em leque, mini player e configurações. Imagens de outros projetos não serão apresentadas como capturas do Oger Dock.

Consulte o [roteiro das capturas](docs/SCREENSHOTS.md).

## Instalação

### Baixar uma versão pronta

Quando a primeira versão pública estiver disponível, os pacotes poderão ser encontrados em [GitHub Releases](https://github.com/dsrsouza/Oger-Dock/releases). Extraia o arquivo do instalador e utilize o script `scripts-user/setup.sh` incluído na pasta do projeto.

### Compilar e instalar pelo código-fonte

Após a publicação do código-fonte completo, execute:

```bash
git clone https://github.com/dsrsouza/Oger-Dock.git
cd Oger-Dock
bash scripts-user/setup.sh --check-deps
bash scripts-user/setup.sh --build-only -j 2
bash scripts-user/setup.sh --install --no-restart -j 2
```

Execute o script com seu usuário normal do ambiente gráfico, sem iniciar a compilação como root. Depois, adicione **Oger Dock** na opção **Adicionar widgets** do KDE Plasma. Pode ser necessário encerrar a sessão e entrar novamente para recarregar um módulo nativo atualizado. Ao atualizar, não apague as suas configurações anteriores.

As dependências por distribuição e as soluções para problemas comuns estão no [guia de instalação em português](docs/INSTALACAO.pt_BR.md) e no [guia em inglês](docs/INSTALLATION.md).

## Compatibilidade

| Ambiente | Situação do projeto |
|---|---|
| openSUSE Tumbleweed + KDE Plasma 6.8.2 + Wayland | Principal ambiente de desenvolvimento e testes com o usuário |
| Outras instalações KDE Plasma 6.8+ | Alvos pretendidos; exigem validação de dependências e bibliotecas nativas |
| Fedora com KDE Plasma 6 | Guia de instalação disponível; homologação completa pendente |
| Debian/Ubuntu com KDE Plasma 6 | Guia de instalação disponível; homologação completa pendente |
| Ambientes sem KDE Plasma | Não suportados |

Os componentes nativos dependem das bibliotecas Qt e KDE instaladas no sistema. Após algumas atualizações do Plasma ou Qt, pode ser necessário recompilar e reinstalar o plasmoide.

**Atualizações de instalações anteriores:** o identificador técnico interno `org.kde.plasma.punchi-dock-remastered` é preservado para manter a continuidade das configurações. O nome público do projeto é **Oger Dock**.

## Testes e qualidade

A preparação da versão 1.0.0 incluiu verificações automatizadas de regressão e dos scripts de instalação. Os resultados anteriores registraram **11/11 testes direcionados** e **13/13 verificações de scripts** aprovados. Essas verificações não substituem compilação nativa, inspeção visual e testes completos em todas as distribuições-alvo.

Um comportamento especificamente confirmado no equipamento do usuário foi a correção da R63.7, que impede a ativação/promoção indevida do MEGA pela rolagem da dock. Os demais recursos devem ser conferidos na release instalada.

Ao relatar um problema, informe a distribuição, a versão do Plasma, a versão do Qt, a sessão Wayland/X11, como reproduzir o erro e os logs relevantes.

## Suporte e comunidade

- **Dúvidas e conversas:** [GitHub Discussions](https://github.com/dsrsouza/Oger-Dock/discussions) (é necessário ativar Discussions nas configurações do repositório).
- **Bugs e sugestões:** [GitHub Issues](https://github.com/dsrsouza/Oger-Dock/issues).
- **Comunidade:** [r/OgerDock no Reddit](https://www.reddit.com/r/OgerDock/).

Contribuições com relatórios de erros, documentação, traduções e testes são bem-vindas. Evite publicar dados pessoais ou sensíveis nos logs.

## Estrutura do projeto

A estrutura prevista para o código-fonte completo contém as seguintes áreas:

```text
contents/       interface QML, JavaScript, ícones e configuração
src/            integração nativa (C++)
scripts-user/   instalação, compilação e verificação de dependências
tests-dev/      testes de regressão e validações de desenvolvimento
metadata.json   metadados do plasmoide KDE Plasma
AGENTS.md       orientações de desenvolvimento com agentes de IA
```

Antes da publicação, a organização final dos arquivos deverá ser conferida no instalador oficial.

### Desenvolvimento com auxílio de inteligência artificial

Ferramentas de IA auxiliaram análises, propostas de implementação, refatorações, testes e documentação. A revisão técnica, as decisões funcionais e a validação final da release continuam sob responsabilidade dos mantenedores. As instruções e os registros de desenvolvimento ficam documentados junto ao código e aos pacotes, quando disponíveis.

## Créditos

**Diego Souza.R**  
**Punchisoft**

## Licença

Oger Dock é distribuído sob a **GNU General Public License versão 3.0 ou posterior (GPL-3.0-or-later)**. O texto integral da licença e os avisos de direitos autorais e atribuição de terceiros aplicáveis devem acompanhar os arquivos publicados. Consulte a [licença GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html).