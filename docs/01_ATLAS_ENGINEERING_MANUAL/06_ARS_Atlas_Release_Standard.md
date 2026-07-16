# ARS — Atlas Release Standard

## Objetivo

El Atlas Release Standard (ARS) define el proceso oficial para publicar nuevas versiones del sistema.

---

# ARS-001 — Toda versión debe ser reproducible

Cada release deberá poder reconstruirse a partir del repositorio.

---

# ARS-002 — Una versión incluye

- código;
- SQL;
- workflows;
- documentación;
- changelog;
- pruebas.

---

# ARS-003 — Checklist

Antes de una liberación deberán validarse:

✓ Migraciones

✓ RPC

✓ Workflows

✓ Documentación

✓ Tests

✓ Changelog

---

# ARS-004 — Versionado

Atlas sigue Semantic Versioning.

Ejemplo:

0.3.0-alpha

---

# ARS-005 — Changelog

Toda liberación genera una nueva entrada en:

Atlas Changelog.

---

# ARS-006 — Releases pequeños

Se priorizan liberaciones frecuentes y controladas.

---

# ARS-007 — Rollback

Toda versión deberá contar con un procedimiento de reversión.

---

# ARS-008 — Principio Final

Una versión representa un estado estable del sistema.

Nunca deberá liberarse una versión que no pueda reproducirse completamente desde el repositorio.
