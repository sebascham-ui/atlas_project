# AWS — Atlas Workflow Standard

## Introducción

El Atlas Workflow Standard (AWS) define las reglas para el diseño, implementación y mantenimiento de todos los workflows de Atlas.

Actualmente el motor de orquestación oficial es n8n.

No obstante, los principios aquí definidos deberán mantenerse aun cuando el motor de orquestación cambie en el futuro.

---

# AWS-001 — Un workflow representa un proceso de negocio

Los workflows no representan tecnologías.

Representan procesos.

Correcto:

Recepción de correo

Nueva reservación

Facturación

Asignación de conductor

Incorrecto:

Workflow Outlook

Workflow OpenAI

Workflow SQL

---

# AWS-002 — La lógica de negocio no vive en el workflow

Los workflows coordinan.

Nunca deciden.

Las reglas del negocio pertenecen al Motor Atlas.

---

# AWS-003 — El Atlas Payload es el contrato oficial

Todo workflow deberá consumir y producir un Atlas Payload.

No deberán construirse contratos alternativos salvo que una integración externa lo requiera.

---

# AWS-004 — Cada nodo tiene una única responsabilidad

Ejemplos:

Leer correo

↓

Interpretar

↓

Normalizar

↓

Enriquecer Payload

↓

Buscar conversación

↓

Crear reservación

↓

Generar respuesta

Cada nodo realiza únicamente una acción.

---

# AWS-005 — El Payload únicamente se enriquece

Un nodo nunca reemplaza completamente el Atlas Payload.

Únicamente añade nueva información.

---

# AWS-006 — Los nombres describen intención

Correcto:

Normalize Atlas Payload

Find Conversation

Create Reservation

Generate Draft

Incorrecto:

Code1

HTTP2

Transform

Nodo Nuevo

---

# AWS-007 — Los Code Nodes son excepcionales

Siempre que sea posible se utilizarán nodos nativos.

Los Code Nodes únicamente se utilizarán cuando:

- exista lógica de transformación;
- sea necesaria una operación no soportada;
- mejore significativamente la claridad.

---

# AWS-008 — Un workflow debe poder reiniciarse

Todo proceso deberá diseñarse para soportar reintentos.

Los módulos críticos deberán ser idempotentes.

---

# AWS-009 — Los errores son información

Todo error deberá contener suficiente contexto para identificar:

- módulo;
- operación;
- causa;
- payload asociado.

---

# AWS-010 — Los workflows son legibles

Un workflow deberá poder comprenderse visualmente.

Se recomienda organizar los nodos por bloques funcionales.

Ejemplo:

Entrada

↓

Interpretación

↓

Construcción del Payload

↓

Motor Atlas

↓

Respuesta

---

# AWS-011 — Los workflows documentan el proceso

Todo workflow importante deberá contar con:

- diagrama;
- descripción;
- caso de prueba;
- referencia al documento correspondiente.

---

# AWS-012 — Principio Final

Los workflows representan la operación del negocio.

Su propósito consiste en coordinar componentes independientes manteniendo el menor acoplamiento posible.
