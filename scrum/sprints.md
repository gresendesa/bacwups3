# Sprints Consolidator

```yaml
section: sprints
schema: schema/sprints.schema.yaml
title: Sprints Consolidator
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
type: consolidator
scope: sprints
detail_directory: scrum/sprints/
tags: [sprints, scrum, memory, consolidator]
```

This file is the synthetic consolidator for project sprints.

Full details for each sprint are stored in dedicated files under `scrum/sprints/`.

[@include: Sprint convention](sprints.md#sprints.convention)
[@ref: Sprint planning policy](CONSTITUTION.md#constitution.sprint-planning)
[@ref: Sprint closing gate](CONSTITUTION.md#constitution.sprint-closing-gate)
[@ref: Sprint memory rule](CONSTITUTION.md#constitution.agent-memory-management.sprints)
[@ref: Backlog consolidator](backlog.md#backlog)

## Objective

```yaml
section: sprints.objective
title: Sprints Objective
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
tags: [objective, sprints]
```

Maintain a concise index of project sprints, keeping only status, focus, PO priority summary, risk, and pointer to the detailed sprint file.

## Convention

```yaml
section: sprints.convention
title: Sprint Convention
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
sprint_id_format: SPR-YYYY-NN
detail_file_pattern: scrum/sprints/SPR-YYYY-NN.md
tags: [convention, sprints, ids]
```

* Sprint ID: `SPR-YYYY-NN`.
* Detailed file: `scrum/sprints/SPR-YYYY-NN.md`.

[@ref: Sprint ID convention](CONSTITUTION.md#constitution.naming-convention.sprints)
[@ref: Sprint detail rule](CONSTITUTION.md#constitution.agent-memory-management.sprint-details)

## Registered Sprints

```yaml
section: sprints.registered
title: Registered Sprints
status: active
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
sprints:
  - SPR-2026-01
  - SPR-2026-02
  - SPR-2026-03
  - SPR-2026-04
  - SPR-2026-05
tags: [sprints, registry]
```

### SPR-2026-01 - Confiabilidade inicial e base operacional

```yaml
section: sprints.SPR-2026-01
sprint_id: SPR-2026-01
title: Confiabilidade inicial e base operacional
status: done
focus: Corrigir identidade do projeto, endurecer falhas de script, isolar temporários e tornar o restore básico confiável.
po_priority_summary: B-001, B-002, B-003 e B-004 possuem PO Priority 1.
sprint_risk: medium
detail_file: scrum/sprints/SPR-2026-01.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: SPR-2026-01 details](sprints/SPR-2026-01.md#sprint.SPR-2026-01)

### SPR-2026-02 - Manifesto seguro e restore defensivo

```yaml
section: sprints.SPR-2026-02
sprint_id: SPR-2026-02
title: Manifesto seguro e restore defensivo
status: done
focus: Validar manifesto, integridade, estrutura de arquivo compactado e rollback para impedir restaurações inseguras ou parciais.
po_priority_summary: B-005, B-006, B-007 e B-008 possuem PO Priority 1.
sprint_risk: high
detail_file: scrum/sprints/SPR-2026-02.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: SPR-2026-02 details](sprints/SPR-2026-02.md#sprint.SPR-2026-02)

### SPR-2026-03 - Backup único e Docker mais seguro

```yaml
section: sprints.SPR-2026-03
sprint_id: SPR-2026-03
title: Backup único e Docker mais seguro
status: done
focus: Substituir versionamento sequencial por IDs únicos, evitar uploads órfãos e endurecer backup de volumes Docker.
po_priority_summary: B-009 e B-010 possuem PO Priority 2.
sprint_risk: medium
detail_file: scrum/sprints/SPR-2026-03.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: SPR-2026-03 details](sprints/SPR-2026-03.md#sprint.SPR-2026-03)

### SPR-2026-04 - Backup de projeto Git

```yaml
section: sprints.SPR-2026-04
sprint_id: SPR-2026-04
title: Backup de projeto Git
status: done
focus: Consolidar backup de projetos Git respeitando .gitignore e registrar metadados Git no manifesto.
po_priority_summary: B-011 e B-012 possuem PO Priority 3.
sprint_risk: high
detail_file: scrum/sprints/SPR-2026-04.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: SPR-2026-04 details](sprints/SPR-2026-04.md#sprint.SPR-2026-04)

### SPR-2026-05 - Verificação e automação essencial

```yaml
section: sprints.SPR-2026-05
sprint_id: SPR-2026-05
title: Verificação e automação essencial
status: done
focus: Adicionar verificação de backup sem restore e consolidar execução local dos testes essenciais.
po_priority_summary: B-013 e B-014 possuem PO Priority 4.
sprint_risk: medium
detail_file: scrum/sprints/SPR-2026-05.md
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
```

[@ref: SPR-2026-05 details](sprints/SPR-2026-05.md#sprint.SPR-2026-05)

### SPR-YYYY-NN Template

```yaml
section: sprints.template.SPR-YYYY-NN
title: Sprint Template
status: template
owner: "gresendesa"
created_at: 2026-07-13
updated_at: 2026-07-13
sprint_id: SPR-YYYY-NN
sprint_status:
focus:
po_priority_summary:
sprint_risk:
detail_file: scrum/sprints/SPR-YYYY-NN.md
tags: [sprints, template]
```

Use this template when registering a new sprint:

```markdown
### SPR-YYYY-NN - Sprint title

```yaml
section: sprints.SPR-YYYY-NN
sprint_id: SPR-YYYY-NN
title: Sprint title
status: planned
focus:
po_priority_summary:
sprint_risk:
detail_file: scrum/sprints/SPR-YYYY-NN.md
owner: "gresendesa"
created_at:
updated_at:
```

Detailed sprint URI: `sprints/SPR-YYYY-NN.md#sprint.SPR-YYYY-NN`
```

[@ref: Risk calculation](CONSTITUTION.md#constitution.sprint-planning.sprint-risk-calculation)
[@ref: PO priority scale](CONSTITUTION.md#constitution.sprint-planning.po-priority-scale)
