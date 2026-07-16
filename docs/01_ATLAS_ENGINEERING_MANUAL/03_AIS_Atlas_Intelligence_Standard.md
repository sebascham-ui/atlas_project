# AIS — Atlas Intelligence Standard

## Introducción

El Atlas Intelligence Standard (AIS) define las reglas para la integración de modelos de Inteligencia Artificial dentro de Atlas.

La IA constituye un componente de interpretación y asistencia.

Nunca representa la fuente de verdad del sistema.

Toda decisión crítica permanece bajo el control del Motor Atlas.

---

# AIS-001 — La IA interpreta

La responsabilidad principal de la IA consiste en transformar información no estructurada en información estructurada.

Ejemplos:

- comprender correos electrónicos;
- interpretar mensajes;
- extraer entidades;
- identificar intención;
- resumir conversaciones;
- generar borradores.

La IA no implementa reglas del negocio.

---

# AIS-002 — La IA nunca decide

Toda decisión empresarial pertenece al Motor Atlas.

La IA podrá realizar propuestas.

Atlas valida.

Atlas persiste.

Atlas decide.

---

# AIS-003 — La IA nunca escribe directamente en la base de datos

El flujo oficial es:

Usuario

↓

IA

↓

Atlas Payload

↓

Motor Atlas

↓

PostgreSQL

Ningún modelo de IA ejecutará operaciones SQL.

---

# AIS-004 — Toda salida deberá ser estructurada

La salida oficial deberá representarse mediante estructuras compatibles con el Atlas Payload.

No se utilizará texto libre cuando exista un contrato estructurado.

---

# AIS-005 — Los prompts son contratos

Los prompts oficiales forman parte del sistema.

Deberán:

- versionarse;
- documentarse;
- probarse;
- mantenerse.

No constituyen instrucciones temporales.

Constituyen componentes de ingeniería.

---

# AIS-006 — La IA trabaja con contexto

La calidad de la respuesta depende de la calidad del contexto disponible.

Siempre que sea posible la IA recibirá:

- conversación;
- historial;
- cliente;
- operación;
- preferencias;
- reglas relevantes.

Nunca únicamente el último mensaje.

---

# AIS-007 — Toda respuesta deberá ser verificable

Las propuestas generadas por IA deberán poder validarse mediante reglas determinísticas.

Atlas nunca confiará ciegamente en una respuesta generada.

---

# AIS-008 — Separación entre interpretación y generación

Atlas distingue claramente dos capacidades:

Interpretación

↓

Comprender información.

Generación

↓

Producir contenido.

Ambas capacidades podrán utilizar modelos diferentes.

---

# AIS-009 — La IA aprende del contexto, no de la base de datos

Los modelos no modifican permanentemente la información.

El aprendizaje operativo ocurre mediante la acumulación de contexto dentro de Atlas.

Las reglas del negocio permanecen explícitas y controladas.

---

# AIS-010 — La IA asiste a las personas

Atlas no busca reemplazar operadores.

Busca reducir carga cognitiva.

Toda acción crítica deberá poder ser revisada por una persona.

---

# AIS-011 — Los modelos son reemplazables

Ningún workflow dependerá de un proveedor específico.

OpenAI constituye la implementación actual.

La arquitectura deberá permitir incorporar otros modelos en el futuro.

---

# AIS-012 — Versionado de Prompts

Todo prompt oficial deberá registrar:

- identificador;
- versión;
- objetivo;
- entradas;
- salidas esperadas;
- fecha de modificación.

Los prompts forman parte del código fuente del sistema.

---

# AIS-013 — Observabilidad

Toda interacción relevante con IA deberá registrar:

- modelo utilizado;
- versión del prompt;
- tiempo de respuesta;
- tokens utilizados;
- resultado;
- posibles errores.

Esta información permitirá evaluar calidad, costos y rendimiento.

---

# AIS-014 — Principio Final

La inteligencia artificial constituye un acelerador de interpretación y asistencia.

La autoridad sobre la operación siempre pertenece al Motor Atlas.
