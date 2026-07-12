# Constituição - bacwups3

```yaml
section: constitution
schema: schema/constitution.schema.yaml
title: Constituição
project_name: bacwups3
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
tags: [governance, constitution, memory, scrum, mdbind]
```

Este documento define a constituição operacional para o espaço de trabalho.

**REGRA CRÍTICA PARA AGENTES DE IA**: Agentes de IA que operam neste espaço de trabalho DEVEM usar a ferramenta CLI `mdb` como seu instrumento principal para navegar, inspecionar e consultar a memória do projeto. Consulte o manual sintético em `mdb.md` para o uso de comandos.

## Objetivo

```yaml
section: constitution.purpose
title: Objetivo
status: active
owner: "gresendesa"
tags: [purpose, governance]
```

Uma ferramenta TUI e cli para criação e recuperação de backups de volumes docker e diretórios para a AWS S3

## Regras Não Negociáveis

```yaml
section: constitution.non-negotiable-rules
title: Regras Não Negociáveis
status: active
owner: "gresendesa"
tags: [rules, governance]
```

* Agentes de IA que operam neste espaço de trabalho devem usar a ferramenta CLI `mdb` como o instrumento principal para navegar, consultar e validar a memória, seguindo [@ref: mdb-manual](mdb.md#template.smd-default.mdb).

* The official project memory lives under the memory root.

* Memory files must use stable section metadata and references.


## Prioridades Estratégicas

```yaml
section: constitution.strategic-priorities
title: Prioridades Estratégicas
status: active
owner: "gresendesa"
tags: [strategy, priorities]
```


* Deliver a small, real MVP first.

* Favor deterministic file operations.


## Política de Memória

```yaml
section: constitution.memory-policy
title: Política de Memória
status: active
owner: "gresendesa"
protected: true
tags: [memory, governance]
```

* Apenas o proprietário aprova mudanças na constituição e na política de memória.

* Consolidators keep concise summaries only.

* Historical records must be marked obsolete instead of deleted.


## Convenção de Nomenclatura

```yaml
section: constitution.naming-convention
title: Convenção de Nomenclatura
status: active
owner: "gresendesa"
tags: [naming, ids, governance]
```

Identificadores estáveis são necessários para itens de backlog, sprints e tarefas.

### Itens de Backlog

```yaml
section: constitution.naming-convention.backlog-items
title: IDs dos Itens de Backlog
status: active
owner: "gresendesa"
id_format: B-XXX
example: B-001
tags: [backlog, ids]
```

* Formato: `B-XXX` (ex. `B-001`).

### Sprints

```yaml
section: constitution.naming-convention.sprints
title: IDs de Sprints
status: active
owner: "gresendesa"
id_format: SPR-YYYY-NN
example: SPR-2026-01
tags: [sprints, ids]
```

* Formato: `SPR-YYYY-NN` (ex. `SPR-2026-01`).

### Tarefas Internas de Sprint

```yaml
section: constitution.naming-convention.sprint-internal-tasks
title: IDs de Tarefas Internas de Sprint
status: active
owner: "gresendesa"
id_format: S{N}-TXX
example: S1-T03
tags: [sprints, tasks, ids]
```

* Formato: `S{N}-TXX` (ex. `S1-T03`).

### Regras de Identificação

```yaml
section: constitution.naming-convention.rules
title: Regras de Identificação
status: active
owner: "gresendesa"
rules:
  ids_reusable: false
  discontinued_status: obsolete
  id_required_before_status: doing
tags: [ids, rules]
```

* IDs não podem ser reutilizados.
* IDs descontinuados devem ser marcados como `obsolete`.
* Novos itens devem receber um ID antes de entrar em `doing`.

## Definição de Concluído (DoD)

```yaml
section: constitution.definition-of-done
title: Definição de Concluído
status: active
owner: "gresendesa"
required_checks:
  - manual_test_documented
  - regression_checklist_executed
  - memory_files_updated
  - rebuilt_container_validation
  - explicit_po_acceptance_before_final_commit
  - automated_tests_successful
tags: [dod, quality, validation]
```

Para marcar qualquer item como `done`:
1. Documentar testes manuais e executar o checklist de regressão.
2. Atualizar os arquivos de memória do Scrum.
3. Validar contêineres reconstruídos e obter aceitação do PO antes do commit.
4. Garantir que todos os testes automatizados passem.

## Planejamento de Sprint

```yaml
section: constitution.sprint-planning
title: Planejamento de Sprint
status: active
owner: "gresendesa"
required: true
tags: [sprint, planning, scrum]
```

As sprints devem ser planejadas com o proprietário. Tarefas são decompostas e riscos calculados.

### Escala de Prioridade do PO

```yaml
section: constitution.sprint-planning.po-priority-scale
title: Escala de Prioridade do PO
status: active
owner: "gresendesa"
scale:
  1: critical
  2: high
  3: medium
  4: low
tags: [priority, planning]
```

* 1 = crítico, 2 = alto, 3 = médio, 4 = baixo.

### Regra de Prioridade do PO

```yaml
section: constitution.sprint-planning.po-priority-rule
title: Regra de Prioridade do PO
status: active
owner: "gresendesa"
required_field: PO Priority
tags: [priority, rule]
```

* Nenhum item pode entrar em uma sprint sem uma `PO Priority` definida.

### Escala de Risco da Tarefa

```yaml
section: constitution.sprint-planning.task-risk-scale
title: Escala de Risco da Tarefa
status: active
owner: "gresendesa"
scale:
  low: 1
  medium: 2
  high: 3
tags: [risk, planning]
```

* low = 1, medium = 2, high = 3.

### Cálculo de Risco da Sprint

```yaml
section: constitution.sprint-planning.sprint-risk-calculation
title: Cálculo de Risco da Sprint
status: active
owner: "gresendesa"
method: simple_weighted_average
classification:
  low: "<= 1.4"
  medium: "> 1.4 and <= 2.3"
  high: "> 2.3"
tags: [risk, planning]
```

* Risco da sprint é a média dos riscos das tarefas: `<= 1.4` (baixo), `<= 2.3` (médio), senão alto.

## Portão de Fechamento de Sprint

```yaml
section: constitution.sprint-closing-gate
title: Portão de Fechamento de Sprint
status: active
owner: "gresendesa"
required: true
tags: [sprint, closing, gate, validation]
```

* Obter aceitação explícita do PO em um ambiente em execução.
* Realizar um commit por sprint.

## Gerenciamento de Memória do Agente

```yaml
section: constitution.agent-memory-management
title: Gerenciamento de Memória do Agente
status: active
owner: "gresendesa"
memory_root: scrum/
tags: [memory, agent, governance]
```

O diretório `scrum/` contém a memória operacional do projeto.

[@include: Configuração do Espaço de Trabalho](CONSTITUTION.md#constitution.agent-memory-management.config)
[@include: Hooks de Sessão do Agente](CONSTITUTION.md#constitution.agent-memory-management.session-hooks)
[@include: Política de Notação MDBind](CONSTITUTION.md#constitution.agent-memory-management.mdbind-notation-policy)
[@ref: Consolidador de Backlog](backlog.md#backlog)
[@ref: Consolidador de Sprints](sprints.md#sprints)
[@ref: Memória de experiência](experience.md#experience)
[@ref: Memória de decisão](decisions.md#decisions)
[@ref: Memória de arquitetura](architecture.md#architecture)
* **Instruções para LLM**: [@ref: llm-instructions](instructions/LLM.md#template.smd-default.instructions) contém regras e diretrizes específicas para agentes de IA que operam neste espaço de trabalho.
* **Manual da CLI mdb**: [@ref: mdb-manual](mdb.md#template.smd-default.mdb) descreve o uso de comandos e diretrizes de navegação para agentes de IA.

### Configuração do Espaço de Trabalho

```yaml
section: constitution.agent-memory-management.config
title: Configuração do Espaço de Trabalho
status: active
owner: "gresendesa"
config_file: .mdb/config.yaml
tags: [config, governance]
```

A configuração reside em `.mdb/config.yaml` para armazenar variáveis e o caminho da raiz da memória.

### Hooks de Sessão do Agente

```yaml
section: constitution.agent-memory-management.session-hooks
title: Hooks de Sessão do Agente
status: active
owner: "gresendesa"
required: true
tags: [hooks, security, governance]
```

Ganchos são injetados nos arquivos de entrada do agente (ex. `AGENTS.md`) apontando para esta constituição. Os agentes devem verificar a frase secreta de 5 palavras.

### Política de Notação MDBind

```yaml
section: constitution.agent-memory-management.mdbind-notation-policy
title: Política de Notação MDBind
status: active
owner: "gresendesa"
tool: mdbind
repository: https://github.com/gresendesa/mdbind
required: true
tags: [mdbind, graph, memory, links]
```

Arquivos Markdown devem usar blocos de metadados YAML e vincular seções usando `@ref` ou `@include`. Execute `mdb validate` antes de fechar sprints.

### Consolidador de Backlog

```yaml
section: constitution.agent-memory-management.backlog
title: Consolidador de Backlog
status: active
owner: "gresendesa"
path: scrum/backlog.md
tags: [backlog, memory]
```

* Caminho: `scrum/backlog.md`. Consolida todos os itens do backlog.

### Detalhes do Item de Backlog

```yaml
section: constitution.agent-memory-management.backlog-items
title: Detalhes do Item de Backlog
status: active
owner: "gresendesa"
path: scrum/backlog/B-XXX.md
tags: [backlog, memory, details]
```

* Caminho: `scrum/backlog/B-XXX.md` para cada item.

### Consolidador de Sprints

```yaml
section: constitution.agent-memory-management.sprints
title: Consolidador de Sprints
status: active
owner: "gresendesa"
path: scrum/sprints.md
tags: [sprints, memory]
```

* Caminho: `scrum/sprints.md`. Consolida todas as sprints.

### Detalhes de Sprint

```yaml
section: constitution.agent-memory-management.sprint-details
title: Detalhes de Sprint
status: active
owner: "gresendesa"
path: scrum/sprints/SPR-YYYY-NN.md
tags: [sprints, memory, details]
```

* Caminho: `scrum/sprints/SPR-YYYY-NN.md` para cada sprint.

### Memória de Arquitetura

```yaml
section: constitution.agent-memory-management.architecture
title: Memória de Arquitetura
status: active
owner: "gresendesa"
path: scrum/architecture.md
tags: [architecture, memory]
```

* Caminho: `scrum/architecture.md`. Registra o design do sistema e os contratos de integração.

### Memória de Experiência

```yaml
section: constitution.agent-memory-management.experience
title: Memória de Experiência
status: active
owner: "gresendesa"
path: scrum/experience.md
tags: [experience, retrospective, incident, memory]
```

* Caminho: `scrum/experience.md`. Registra retrospectivas e relatórios de incidentes.

### Memória de Decisão

```yaml
section: constitution.agent-memory-management.decisions
title: Memória de Decisão
status: active
owner: "gresendesa"
path: scrum/decisions.md
tags: [decisions, governance, memory]
```

* Caminho: `scrum/decisions.md`. Registra as escolhas de governança de processos e memória.

### Regra de Histórico

```yaml
section: constitution.agent-memory-management.history
title: Regra de Histórico
status: active
owner: "gresendesa"
history_deletion_allowed: false
obsolete_required_fields: [date, reason]
tags: [history, governance]
```

* O histórico não deve ser excluído. Registros antigos são marcados como `obsolete` com data e motivo.

## Padrão de Registro

```yaml
section: constitution.record-standard
title: Padrão de Registro
status: active
owner: "gresendesa"
required_fields:
  - status
  - owner
  - created_at
  - updated_at
tags: [records, metadata]
```

Todos os arquivos sob `scrum/` devem declarar `status`, `owner`, `created_at` e `updated_at`.

### Status Padrão

```yaml
section: constitution.record-standard.statuses
title: Status Padrão
status: active
owner: "gresendesa"
statuses:
  - todo
  - doing
  - blocked
  - done
  - obsolete
tags: [status, records]
```

* Statuses: `todo`, `doing`, `blocked`, `done`, `obsolete`.

## Validade e Alterações

```yaml
section: constitution.validity-and-changes
title: Validade e Alterações
status: active
owner: "gresendesa"
effective: immediately
change_approval_required_by: owner
tags: [governance, changes]
```

Esta constituição entra em vigor imediatamente. Alterações requerem aprovação do proprietário.
