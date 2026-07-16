# APS — Atlas Payload Standard

## Objetivo

El Atlas Payload Standard (APS) define la especificación oficial del contrato de datos utilizado por todos los componentes de Atlas.

El Atlas Payload constituye el único objeto de intercambio de información entre módulos.

---

# APS-001 — Contrato único

Todo proceso de negocio utiliza exactamente un Atlas Payload.

No deberán existir payloads paralelos para procesos internos.

---

# APS-002 — Estructura estable

La estructura raíz permanece constante.

```json
{
  "conversation": {},
  "client": {},
  "account": {},
  "reservation": {},
  "services": [],
  "metadata": {}
}
```

Los nuevos módulos únicamente añadirán nuevos bloques.

---

# APS-003 — Enriquecimiento progresivo

Cada componente:

1. recibe el Atlas Payload;
2. agrega información;
3. devuelve el mismo Atlas Payload.

Nunca reemplaza el contrato.

---

# APS-004 — Compatibilidad

Los cambios deberán ser compatibles con versiones anteriores.

Nunca eliminar campos existentes sin una estrategia formal de migración.

---

# APS-005 — Trazabilidad

Todo identificador persistente obtenido durante un proceso deberá incorporarse al payload.

Ejemplo:

- person_id
- account_id
- conversation_thread_id
- service_order_id

---

# APS-006 — Independencia tecnológica

El Atlas Payload no depende de:

- OpenAI;
- n8n;
- Supabase;
- PostgreSQL.

Constituye un contrato del dominio Atlas.

---

# APS-007 — Versionado

Si el contrato cambia de forma incompatible deberá incrementarse la versión mayor del payload y documentarse mediante un ADR.

---

# APS-008 — Principio Final

El Atlas Payload representa el contexto operativo del proceso.

Su estabilidad constituye uno de los pilares arquitectónicos del sistema.
