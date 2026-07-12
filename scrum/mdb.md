# mdb — Manual de Referência Sintético do MdBind CLI

```yaml
section: template.smd-default.mdb
title: Manual Sintético da CLI mdb
status: active
template: smd-default
tags: [template, manual, mdb, smd]
```

Este manual fornece uma referência sintética da ferramenta `mdb` CLI para agentes de IA e desenvolvedores. Agentes de IA operando neste espaço de trabalho DEVEM usar `mdb` como a ferramenta principal para navegar, consultar, validar e compor o grafo de memória.

## 1. Conceitos Fundamentais

- **URI de Seção**: Cada seção em um arquivo Markdown é um nó no grafo, identificado por `caminho/para/arquivo.md#id-da-secao`.
- **Bloco de Metadados**: Toda seção válida começa com um cabeçalho YAML imediatamente após seu título:
  ```text
  section: id-da-secao
  title: Título da Seção
  status: active
  ```
- **Diretrizes**:
  - `[@ref: rotulo](caminho/para/arquivo.md#id-da-secao)`: Cria um link de dependência direcional.
  - `[@include: rotulo](caminho/para/arquivo.md#id-da-secao)`: Indica uma inclusão/transclusão para embutir o conteúdo de destino durante a composição.

## 2. Referência de Comandos da CLI

### Consultas e Recuperação do Grafo
- `mdb get <URI>`: Extrai o conteúdo markdown original de uma seção com 100% de fidelidade.
- `mdb tree <URI>`: Mostra a hierarquia de inclusões e referências a partir de um nó.
- `mdb compose <URI> [--deduplicate]`: Resolve inclusões recursivamente para construir um único documento composto.
- `mdb backlinks <URI>`: Descobre todas as seções que apontam para a URI de destino.
- `mdb search <predicado>`: Busca seções por pares de chave/valor de metadados (ex: `tags=rules`, `status=todo`).
- `mdb query <expressao>`: Realiza correspondência de expressões de consulta avançadas.
- `mdb neighbors <URI> [--depth N]`: Descobre nós adjacentes no grafo de memória.
- `mdb explain <URI_A> <URI_B>`: Rastreia caminhos e conexões entre dois nós.
- `mdb impact <URI>`: Mostra os nós a jusante afetados por alterações em uma seção.
- `mdb diff <URI> [--since <git-ref>]`: Compara alterações semânticas em relação ao histórico do Git.

### Geração de Contexto para LLMs
- `mdb context <URI>`: Constrói um payload de prompt estruturado com a seção de destino e dependências diretas.
- `mdb context-compose <URI> [--token-limit N]`: Compõe recursivamente seções descendentes dentro de um limite de tokens.

### Validação e Scaffolding
- `mdb validate [--root <caminho> | --file <caminho.md>]`: Valida conformidade com esquemas, detecta ciclos, referências quebradas e verifica a conformidade mínima do template (todos os arquivos markdown alcançáveis a partir de `CONSTITUTION.md`).
- `mdb init --template <pacote|URL>`: Inicializa um novo espaço de trabalho a partir de um template.
- `mdb pack <diretorio> --output <nome_arquivo.zip>`: Empacota um diretório de espaço de trabalho em um pacote de template.
- `mdb metadata get|update|unset <URI>`: Interage com os metadados dinâmicos de uma seção.

## 3. Fluxo de Trabalho de Navegação Recomendado para Agentes de IA

1. **Orientação**: Execute `mdb validate` para garantir a integridade do espaço de trabalho.
2. **Verificação Constitucional**: Execute `mdb get CONSTITUTION.md#constitution` para ler as regras e caminhos de memória ativos.
3. **Acompanhamento de Tarefas**: Execute `mdb get backlog.md#backlog` para inspecionar os itens de backlog ativos.
4. **Recuperação de Contexto**: Use `mdb context-compose` ou `mdb compose` nos nós de tarefas ativas para construir o contexto completo antes de executar alterações de código.
