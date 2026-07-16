# 6. Atlas Payload

## 6.1 Introducción

El Atlas Payload constituye el contrato oficial de intercambio de información dentro del sistema Atlas.

Representa el estado completo de un proceso de negocio durante su ejecución y permite que todos los componentes compartan un mismo contexto sin depender directamente entre sí.

El Atlas Payload no es una entidad persistente.

Es un objeto temporal que evoluciona progresivamente conforme Atlas adquiere mayor conocimiento del proceso.

---

# 6.2 Objetivo

El Atlas Payload elimina la necesidad de construir múltiples contratos entre componentes.

En su lugar, todo el sistema comparte una única representación del proceso.

Esto garantiza consistencia, trazabilidad y escalabilidad.

---

# 6.3 Principios

El Atlas Payload se rige por los siguientes principios:

• Existe un único payload por proceso.

• Nunca cambia su estructura principal.

• Cada componente únicamente agrega información.

• Ningún componente elimina información previamente validada.

• Todo enriquecimiento debe mantener compatibilidad hacia atrás.

---

# 6.4 Estructura Oficial

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

Esta estructura constituye el contrato oficial entre todos los módulos de Atlas.

---

# 6.5 Ciclo de Vida

Durante un workflow el Atlas Payload evoluciona continuamente.

Estado inicial:

```json
{
}
```

↓

Después de OpenAI

```json
{
    "client": {...},
    "reservation": {...},
    "services": [...]
}
```

↓

Después de Conversation Engine

```json
{
    "conversation": {
        "thread_id":"..."
    }
}
```

↓

Después de Reservation Engine

```json
{
    "client":{
        "person_id":"..."
    },

    "account":{
        "account_id":"..."
    },

    "reservation":{
        "service_order_id":"..."
    }
}
```

↓

Después de futuros módulos

```json
{
    ...
    "dispatch":{},
    "pricing":{},
    "billing":{},
    "analytics":{}
}
```

---

# 6.6 Enriquecimiento

Cada módulo sigue exactamente el mismo patrón.

Entrada

↓

Lee Atlas Payload

↓

Realiza una operación

↓

Agrega nueva información

↓

Devuelve el Atlas Payload

Ningún módulo genera un payload alternativo.

---

# 6.7 Compatibilidad

Las nuevas versiones de Atlas deberán mantener compatibilidad con la estructura oficial del payload.

Cuando sea necesario incorporar nuevos bloques, éstos deberán añadirse sin modificar los existentes.

Ejemplo:

```json
{
    ...
    "pricing":{},
    "dispatch":{}
}
```

Nunca reemplazando:

```json
{
    "reservation":{}
}
```

---

# 6.8 Beneficios

El Atlas Payload proporciona:

- contexto unificado;
- desacoplamiento entre módulos;
- facilidad de pruebas;
- escalabilidad;
- reutilización;
- compatibilidad entre integraciones.

---

# 6.9 Diagrama

```mermaid
flowchart LR

A[Evento]

--> B[OpenAI]

--> C[Atlas Payload]

--> D[Conversation Engine]

--> E[Reservation Engine]

--> F[Dispatch Engine]

--> G[Billing Engine]

--> H[Analytics Engine]

Cada motor únicamente enriquece el mismo Atlas Payload.
```

---

# 6.10 Regla Fundamental

El Atlas Payload constituye el contrato oficial del sistema.

Todo nuevo módulo deberá consumir y producir este contrato.

No deberán existir contratos paralelos salvo que una integración externa lo requiera explícitamente.
