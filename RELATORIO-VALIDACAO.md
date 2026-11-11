# Oger Dock 1.0.0 — Relatório de validação do pacote

Data: 10/11/2026. Base funcional R63.7.

- Identidade: Oger Dock 1.0.0; autores Diego Souza.R e Punchisoft, em registros independentes; domínio/ID técnico anterior preservado.
- Idiomas: catálogos `en`, `pt_BR`, `es`, `de` presentes. Inglês: 1.618 mensagens de origem e 0 problemas pelo validador Babel; os quatro catálogos puderam ser convertidos em `.mo` por Babel. A validação `msgfmt` nativa não estava disponível aqui.
- Testes de regressão curados (Node.js): **11/11 aprovados**. Incluem os fluxos R63.3–R63.7 de tray, hover, cores de pastas e scroll.
- Scripts de usuário e teste: **13/13** com sintaxe Bash válida. `setup.sh --help` executou corretamente.
- Compilação nativa: **NÃO CONCLUÍDA**, falta pacote ECM >= 6.0 no ambiente de preparação; não declarar como validado no Plasma.
- Instalador completo **a partir do código-fonte**: usa `scripts-user/setup.sh`, gera `.plasmoid` localmente no host com ECM/KF6/Qt6. Não inclui `.plasmoid` universal pré-compilado.
- O pacote principal preserva as fontes e os scripts essenciais, e inclui instruções e histórico técnico para IA. Arquivos descontinuados estão no ZIP histórico opcional.
- A correção de scroll que não ativa MEGA exclusivamente na tray foi confirmada pelo usuário na R63.7. Outros fluxos exigem teste no Plasma 6.8.2 real antes da homologação final.
