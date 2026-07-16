# AGS — Atlas Git Standard

## Objetivo

El Atlas Git Standard (AGS) define la organización del repositorio, la estrategia de commits y el control de versiones.

---

# AGS-001 — Un repositorio

Todo el proyecto Atlas reside en un único repositorio.

Código, documentación, workflows y activos evolucionan conjuntamente.

---

# AGS-002 — Organización

```
atlas_project/

docs/

sql/

n8n/

prompts/

tests/

scripts/

assets/
```

---

# AGS-003 — Commits atómicos

Cada commit representa un único avance lógico.

Correcto:

feat(conversation): create thread engine

Incorrecto:

misc updates

---

# AGS-004 — Convención de commits

Tipos oficiales:

docs

feat

fix

refactor

test

style

perf

chore

---

# AGS-005 — Documentación

Toda modificación relevante deberá actualizar la documentación correspondiente antes del merge.

---

# AGS-006 — Versionado

Atlas utiliza Semantic Versioning.

MAJOR.MINOR.PATCH

---

# AGS-007 — Trazabilidad

Todo ADR, estándar y documento deberá poder relacionarse con uno o más commits.

---

# AGS-008 — Principio Final

El historial Git constituye la memoria técnica del proyecto.
