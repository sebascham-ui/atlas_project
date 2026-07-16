# ADS — Atlas Database Standard

## Introducción

El Atlas Database Standard (ADS) define las reglas oficiales para el diseño, implementación y mantenimiento de la base de datos Atlas.

Su objetivo es garantizar consistencia, reutilización y escalabilidad.

Toda implementación SQL deberá cumplir este estándar.

---

# ADS-001 — Una función, una responsabilidad

Cada función implementa una única operación de negocio.

Correcto:

person()

account()

create_reservation()

Incorrecto:

create_person_account_reservation()

---

# ADS-002 — El negocio vive en atlas

Toda lógica empresarial deberá implementarse exclusivamente dentro del esquema:

atlas

Ningún cliente externo implementará reglas de negocio.

---

# ADS-003 — Las integraciones consumen public

Las aplicaciones externas nunca ejecutan funciones atlas directamente.

Siempre utilizarán wrappers públicos.

```
Aplicación

↓

public.*

↓

atlas.*
```

---

# ADS-004 — JSONB como contrato

Toda operación compleja utilizará un único parámetro JSONB.

Ejemplo:

```sql
p_payload jsonb
```

El payload deberá seguir la especificación oficial definida en APS.

---

# ADS-005 — Idempotencia

Siempre que el dominio lo permita, una función deberá producir el mismo resultado cuando reciba el mismo contexto.

Ejemplos:

- person()

- account()

- find_or_create_conversation_thread()

---

# ADS-006 — Funciones reutilizables

Las funciones deberán componerse.

Ejemplo:

create_reservation()

↓

person()

↓

account()

↓

create_service_order()

No deberá duplicarse lógica.

---

# ADS-007 — Salidas enriquecidas

Las funciones devolverán información útil.

Ejemplo:

```json
{
    "success": true,
    "person_id": "...",
    "account_id": "...",
    "service_order_id": "...",
    "warnings": []
}
```

Nunca devolver únicamente TRUE o FALSE cuando exista información relevante.

---

# ADS-008 — Catálogos

Los valores constantes deberán residir en catalog_groups y catalog_items.

Nunca utilizar valores mágicos distribuidos por el código.

---

# ADS-009 — Migraciones

Todo cambio estructural deberá realizarse mediante una migración.

Nunca modificar manualmente una versión histórica.

---

# ADS-010 — Documentación

Toda función deberá existir en:

- Data Dictionary
- API Reference
- Test Catalog

---

# ADS-011 — Convención de nombres

Variables

v_

Parámetros

p_

Constantes

c_

Cursores

cur_

Ejemplo

v_person_id

p_payload

c_status_open

---

# ADS-012 — Principio Final

La base de datos constituye el núcleo operativo de Atlas.

Toda decisión que incremente la claridad, mantenibilidad o reutilización del motor Atlas deberá priorizarse sobre soluciones rápidas de corto plazo.
