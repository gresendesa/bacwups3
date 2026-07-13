# Backlog Consolidator

```yaml
section: backlog
schema: schema/backlog.schema.yaml
title: Backlog Consolidator
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
type: consolidator
scope: backlog
detail_directory: scrum/backlog/
tags: [backlog, scrum, memory, consolidator]
```

This file is the synthetic consolidator for backlog items.

Full details for each backlog item are stored in dedicated files under `scrum/backlog/`.

[@include: Backlog convention](backlog.md#backlog.convention)
[@ref: Constitution backlog rules](CONSTITUTION.md#constitution.agent-memory-management.backlog)
[@ref: Backlog ID convention](CONSTITUTION.md#constitution.naming-convention.backlog-items)
[@ref: PO priority rule](CONSTITUTION.md#constitution.sprint-planning.po-priority-rule)

## Objective

```yaml
section: backlog.objective
title: Backlog Objective
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
tags: [objective, backlog]
```

Maintain a concise index of backlog items, keeping only the fields required for planning, tracking, and navigation.

Detailed scope, acceptance criteria, dependencies, owner, and history must remain in the corresponding item file.

## Convention

```yaml
section: backlog.convention
title: Backlog Convention
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
item_id_format: B-XXX
detail_file_pattern: scrum/backlog/B-XXX.md
tags: [convention, backlog, ids]
```

* Backlog item ID: `B-XXX`.
* Detailed file: `scrum/backlog/B-XXX.md`.

[@ref: Backlog item details rule](CONSTITUTION.md#constitution.agent-memory-management.backlog-items)

## Synthetic Item Summary

```yaml
section: backlog.synthetic-summary
title: Synthetic Item Summary
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
groups:
  - done
  - pending
  - planned
  - doing
  - review
tags: [summary, backlog]
```

This section groups backlog items by operational status.

## Essential Backlog Guidelines

```yaml
section: backlog.guidelines.essential
title: Essential Backlog Guidelines
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
tags: [backlog, guidelines, bash, mvp]
```

* Keep the project in Bash.
* All backups are complete and independent.
* Do not implement incremental backup.
* Preserve the existing TUI.
* Avoid new dependencies unless necessary.

## Essential Backlog Implementation Order

```yaml
section: backlog.implementation-order.essential
title: Essential Backlog Implementation Order
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
tags: [backlog, implementation-order]
```

1. B-001 até B-008: corrigir confiabilidade e segurança.
2. B-009 e B-010: fortalecer o processo de backup.
3. B-011 e B-012: implementar backup de projetos.
4. B-013 e B-014: verificação e testes.

### Done

```yaml
section: backlog.synthetic-summary.done
title: Done Backlog Items
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
item_status: done
items:
  - B-001
  - B-002
  - B-003
  - B-004
  - B-005
  - B-006
  - B-007
  - B-008
  - B-009
  - B-010
  - B-011
  - B-012
  - B-013
  - B-014
  - B-015
  - B-016
tags: [backlog, done]
```

### B-001 - Corrigir nomenclatura e documentação

```yaml
section: backlog.item.B-001.done
id: B-001
title: Corrigir nomenclatura e documentação
status: done
po_priority: 1
risk: low
detail_file: scrum/backlog/B-001.md
linked_sprint: SPR-2026-01
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-001 details](backlog/B-001.md#backlog.item.B-001)

### B-002 - Habilitar tratamento rigoroso de erros

```yaml
section: backlog.item.B-002.done
id: B-002
title: Habilitar tratamento rigoroso de erros
status: done
po_priority: 1
risk: medium
detail_file: scrum/backlog/B-002.md
linked_sprint: SPR-2026-01
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-002 details](backlog/B-002.md#backlog.item.B-002)

### B-003 - Criar workspace temporário seguro

```yaml
section: backlog.item.B-003.done
id: B-003
title: Criar workspace temporário seguro
status: done
po_priority: 1
risk: medium
detail_file: scrum/backlog/B-003.md
linked_sprint: SPR-2026-01
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-003 details](backlog/B-003.md#backlog.item.B-003)

### B-004 - Tornar o restore confiável

```yaml
section: backlog.item.B-004.done
id: B-004
title: Tornar o restore confiável
status: done
po_priority: 1
risk: high
detail_file: scrum/backlog/B-004.md
linked_sprint: SPR-2026-01
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-004 details](backlog/B-004.md#backlog.item.B-004)

### B-005 - Gerar e validar o manifesto com JSON seguro

```yaml
section: backlog.item.B-005.done
id: B-005
title: Gerar e validar o manifesto com JSON seguro
status: done
po_priority: 1
risk: medium
detail_file: scrum/backlog/B-005.md
linked_sprint: SPR-2026-02
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-005 details](backlog/B-005.md#backlog.item.B-005)

### B-006 - Fortalecer a validação de integridade

```yaml
section: backlog.item.B-006.done
id: B-006
title: Fortalecer a validação de integridade
status: done
po_priority: 1
risk: medium
detail_file: scrum/backlog/B-006.md
linked_sprint: SPR-2026-02
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-006 details](backlog/B-006.md#backlog.item.B-006)

### B-007 - Validar o arquivo compactado antes da extração

```yaml
section: backlog.item.B-007.done
id: B-007
title: Validar o arquivo compactado antes da extração
status: done
po_priority: 1
risk: high
detail_file: scrum/backlog/B-007.md
linked_sprint: SPR-2026-02
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-007 details](backlog/B-007.md#backlog.item.B-007)

### B-008 - Implementar rollback de restore incompleto

```yaml
section: backlog.item.B-008.done
id: B-008
title: Implementar rollback de restore incompleto
status: done
po_priority: 1
risk: high
detail_file: scrum/backlog/B-008.md
linked_sprint: SPR-2026-02
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-008 details](backlog/B-008.md#backlog.item.B-008)

### B-009 - Evitar colisões e uploads incompletos

```yaml
section: backlog.item.B-009.done
id: B-009
title: Evitar colisões e uploads incompletos
status: done
po_priority: 2
risk: medium
detail_file: scrum/backlog/B-009.md
linked_sprint: SPR-2026-03
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-009 details](backlog/B-009.md#backlog.item.B-009)

### B-010 - Tornar o backup de volumes Docker mais seguro

```yaml
section: backlog.item.B-010.done
id: B-010
title: Tornar o backup de volumes Docker mais seguro
status: done
po_priority: 2
risk: low
detail_file: scrum/backlog/B-010.md
linked_sprint: SPR-2026-03
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-010 details](backlog/B-010.md#backlog.item.B-010)

### B-011 - Adicionar backup de projeto respeitando .gitignore

```yaml
section: backlog.item.B-011.done
id: B-011
title: Adicionar backup de projeto respeitando .gitignore
status: done
po_priority: 3
risk: high
detail_file: scrum/backlog/B-011.md
linked_sprint: SPR-2026-04
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-011 details](backlog/B-011.md#backlog.item.B-011)

### B-012 - Registrar informações Git no manifesto

```yaml
section: backlog.item.B-012.done
id: B-012
title: Registrar informações Git no manifesto
status: done
po_priority: 3
risk: medium
detail_file: scrum/backlog/B-012.md
linked_sprint: SPR-2026-04
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-012 details](backlog/B-012.md#backlog.item.B-012)

### B-013 - Adicionar verificação de backup sem restaurar

```yaml
section: backlog.item.B-013.done
id: B-013
title: Adicionar verificação de backup sem restaurar
status: done
po_priority: 4
risk: medium
detail_file: scrum/backlog/B-013.md
linked_sprint: SPR-2026-05
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-013 details](backlog/B-013.md#backlog.item.B-013)

### B-014 - Adicionar testes automatizados essenciais

```yaml
section: backlog.item.B-014.done
id: B-014
title: Adicionar testes automatizados essenciais
status: done
po_priority: 4
risk: medium
detail_file: scrum/backlog/B-014.md
linked_sprint: SPR-2026-05
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-014 details](backlog/B-014.md#backlog.item.B-014)

### B-015 - Suportar IAM restrito a bucket único

```yaml
section: backlog.item.B-015.done
id: B-015
title: Suportar IAM restrito a bucket único
status: done
po_priority: 1
risk: medium
detail_file: scrum/backlog/B-015.md
linked_sprint: null
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-015 details](backlog/B-015.md#backlog.item.B-015)

### B-016 - Incluir .git no backup de projeto Git

```yaml
section: backlog.item.B-016.done
id: B-016
title: Incluir .git no backup de projeto Git
status: done
po_priority: 1
risk: high
detail_file: scrum/backlog/B-016.md
linked_sprint: SPR-2026-06
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-016 details](backlog/B-016.md#backlog.item.B-016)

### Pending

```yaml
section: backlog.synthetic-summary.pending
title: Pending Backlog Items
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
item_status: pending
items: []
tags: [backlog, pending]
```

No items registered.

### Planned

```yaml
section: backlog.synthetic-summary.planned
title: Planned Backlog Items
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
item_status: planned
items: []
tags: [backlog, planned]
```

No items registered.

### Review

```yaml
section: backlog.synthetic-summary.review
title: Backlog Items In Review
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
item_status: review
items: []
tags: [backlog, review]
```

No items registered.

### B-001 - Corrigir nomenclatura e documentação

```yaml
section: backlog.item.B-001
id: B-001
title: Corrigir nomenclatura e documentação
status: todo
po_priority: 1
risk: low
detail_file: scrum/backlog/B-001.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-001 details](backlog/B-001.md#backlog.item.B-001)

### B-002 - Habilitar tratamento rigoroso de erros

```yaml
section: backlog.item.B-002
id: B-002
title: Habilitar tratamento rigoroso de erros
status: todo
po_priority: 1
risk: medium
detail_file: scrum/backlog/B-002.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-002 details](backlog/B-002.md#backlog.item.B-002)

### B-003 - Criar workspace temporário seguro

```yaml
section: backlog.item.B-003
id: B-003
title: Criar workspace temporário seguro
status: todo
po_priority: 1
risk: medium
detail_file: scrum/backlog/B-003.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-003 details](backlog/B-003.md#backlog.item.B-003)

### B-004 - Tornar o restore confiável

```yaml
section: backlog.item.B-004
id: B-004
title: Tornar o restore confiável
status: todo
po_priority: 1
risk: high
detail_file: scrum/backlog/B-004.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: B-004 details](backlog/B-004.md#backlog.item.B-004)

### Doing

```yaml
section: backlog.synthetic-summary.doing
title: Backlog Items In Progress
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
item_status: doing
items: []
tags: [backlog, doing]
```

## Synthetic Template for New Items

```yaml
section: backlog.template.synthetic-item
title: Synthetic Template for New Backlog Items
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
template_fields:
  - id
  - title
  - status
  - po_priority
  - risk
  - detail_file
allowed_statuses:
  - todo
  - doing
  - blocked
  - done
  - obsolete
tags: [template, backlog]
```

Use this template when adding a new backlog item to the consolidator:

```markdown
### B-XXX - Item title

```yaml
section: backlog.item.B-XXX
id: B-XXX
title: Item title
status: todo
po_priority:
risk:
detail_file: scrum/backlog/B-XXX.md
owner: "gresendesa"
created_at:
updated_at:
```

Detailed backlog item URI: `backlog/B-XXX.md#backlog.item.B-XXX`
```

[@ref: Record standard](CONSTITUTION.md#constitution.record-standard)
[@ref: Default statuses](CONSTITUTION.md#constitution.record-standard.statuses)
