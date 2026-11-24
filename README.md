# Limpador

Aplicativo nativo em Swift e SwiftUI para analisar armazenamento e revisar a limpeza local do Mac. A Lupa de Espaço é uma das funções principais. Integrações com nuvem e email estão fora do escopo.

## Lupa de Espaço

Abra **Lupa de Espaço → Escolher pasta**, use o atalho **Downloads** ou selecione um **volume local**.

- O mapa usa blocos proporcionais aos tamanhos lógicos encontrados. Um clique seleciona; dois cliques entram na pasta ou abrem a visualização do arquivo.
- Navegue pelo caminho no topo ou pelo botão de subir um nível. A navegação reutiliza a leitura concluída.
- Filtre pelo nome e escolha se deseja mostrar arquivos ocultos. A tabela também inclui itens pequenos, pastas vazias e entradas cujo tamanho não pôde ser determinado.
- Consulte detalhes, abra o Finder e revise os arquivos da pasta ou do item selecionado. A revisão começa sem seleção; o envio à Lixeira exige confirmação.
- A leitura mostra progresso observado e permite cancelamento. Exclusões, links não seguidos e falhas de acesso permanecem visíveis.
- Depois de uma limpeza, o mapa informa que precisa ser reanalisado.

O mapa não representa espaço fisicamente recuperável. Hard links, clones, compressão, snapshots e metadados podem fazer os números diferirem do uso do volume. Enviar à Lixeira não libera espaço imediatamente. A Lupa não segue links simbólicos e aceita apenas volumes identificados como locais pelo macOS.

## Status das funções

| Área | Implementado | Limites atuais |
| --- | --- | --- |
| Interface | Navegação, temas, preferências e inventário real | macOS 14 ou posterior declarado; versões antigas ainda precisam de validação em máquina real |
| Lupa de Espaço | Mapa interativo, navegação, busca, ocultos, tabela, detalhes e revisão | Fotografia da leitura; atualização por nova análise |
| Limpeza local | Caches, registros, temporários, candidatos a instaladores e leitura da Lixeira | Sem exclusão permanente ou esvaziamento da Lixeira |
| Revisão | Nome, tipo, tamanho, idade, Quick Look e Finder | Cada remoção depende da seleção e confirmação |
| Duplicados | Comparação de conteúdo com SHA-256 | Sem identificação de imagens apenas semelhantes |
| Remoção | Identidades verificadas, proteção de áreas sensíveis e relatórios por arquivo | Arquivos alterados, protegidos ou associados a aplicativos em execução podem ser ignorados |
| Recuperação | Destino na Lixeira, instruções de restauração e histórico | Restauração dos arquivos pelo Finder |
| Aplicativos | Inventário, ordenação por nome/tamanho, dados associados e desinstalação revisada | Dados compartilhados e associações incertas não são tratados como exclusivos |
| Sobras | Candidatos a dados de apps ausentes | Ausência no inventário não comprova que os dados sejam dispensáveis |
| Preferências de apps | Backup, redefinição e restauração do domínio padrão | Não redefine todos os formatos de configuração de um aplicativo |
| Atualizações | Consulta manual a feeds HTTPS declarados e links oficiais | Sem instalação automática; comparação de versão não comprova compatibilidade |
| Monitoramento | CPU, memória, disco, bateria e processos de apps gráficos | Não soma todos os serviços e processos auxiliares |
| Inicialização | Inventário de agentes, daemons, extensões e auxiliares declarados | Presença não comprova ativação; alterações pelo painel oficial do macOS |
| Avisos e lembretes | Opções de pouco espaço, barra de menus e lembretes de análise | Ativação opcional; nenhuma limpeza agendada automaticamente |
| Permissões | Diagnóstico por pasta, falhas parciais e orientação de acesso | O usuário concede as permissões no macOS |
| Distribuição local | Ícone, pacote universal, assinatura ad hoc e instalador com backup | Developer ID e notarização adiados por decisão do usuário |
| Atualização do Limpador | Consulta manual às releases do projeto | Sem baixar ou instalar executáveis automaticamente |

## Validação e pendências

- [x] Suíte local aprovada no Mac Apple Silicon de desenvolvimento: 40 testes executados e um teste opcional de Lixeira ignorado, incluindo quatro testes da Lupa executados.
- [x] Interface da Lupa verificada com arquivos próprios: mapa, navegação, ocultos e revisão.
- [x] Compilação universal com `arm64` e `x86_64`; assinatura local verificada.
- [x] Instalador verificado em destino temporário, incluindo segunda execução idempotente.
- [x] Testes e compilação de produção aprovados nos runners nativos Apple Silicon (`macos-15`) e Intel (`macos-15-intel`), na [execução 45467837919](https://github.com/Wilton-Garcia/Limpador/actions/runs/45467837919), commit `98936dd`. Compilação cruzada permanece distinta de execução nativa.
- [ ] Validar o aplicativo em versões anteriores do macOS e em hardware Intel.
- [ ] Configurar Developer ID e notarização quando o usuário decidir preparar a distribuição pública.

A lista descreve as capacidades implementadas do Limpador. Não representa comprovação de equivalência integral com outro aplicativo. Antimalware, reparos de sistema, gerenciamento de snapshots, limpeza específica de navegadores e reconhecimento de imagens semelhantes não estão implementados.

## Compilar e executar

Requer o toolchain Swift 6 ou posterior, com as ferramentas de desenvolvimento do macOS.

```sh
swift test
scripts/build-app.sh
open build/Limpador.app
```

Para compilar as duas arquiteturas e gerar o ZIP local:

```sh
scripts/package-release.sh
```

O aplicativo fica em `build/Limpador.app` e o pacote em `build/Limpador-local.zip`. Esses artefatos não são versionados.

Para revisar e instalar na pasta de aplicativos do usuário:

```sh
scripts/install-local.sh --dry-run
scripts/install-local.sh
```

O instalador solicita confirmação e preserva uma versão anterior. Assinatura Developer ID e notarização exigem configuração externa; o fluxo padrão produz somente uma compilação local com assinatura ad hoc.

As análises e limpezas são locais. As consultas manuais de atualização acessam os servidores indicados na interface; não enviam o inventário dos arquivos analisados.
