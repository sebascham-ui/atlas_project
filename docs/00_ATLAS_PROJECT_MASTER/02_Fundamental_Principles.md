# 2. Principios Fundamentales

## Introducción

Los principios fundamentales constituyen las reglas inmutables sobre las que se construye Atlas.

Toda decisión técnica, arquitectónica o funcional deberá respetar estos principios. Cuando una solución entre en conflicto con alguno de ellos, deberá replantearse antes de ser implementada.

---

# PF-001 — La IA interpreta; Atlas decide.

La Inteligencia Artificial tiene como responsabilidad comprender lenguaje natural, clasificar información, extraer entidades y generar propuestas.

Atlas conserva la responsabilidad absoluta sobre las reglas de negocio.

La IA nunca toma decisiones operativas finales.

Ejemplos:

✓ Interpretar un correo electrónico.

✓ Detectar origen, destino y fechas.

✓ Identificar intención del cliente.

✓ Generar un borrador de respuesta.

Pero nunca:

✗ Crear reglas de negocio.

✗ Modificar estados críticos.

✗ Validar procesos empresariales.

✗ Autorizar operaciones.

---

# PF-002 — PostgreSQL es la fuente única de verdad.

Toda información permanente deberá persistirse en PostgreSQL.

Ningún workflow, modelo de IA o integración externa podrá convertirse en la fuente principal de datos.

Toda lectura crítica deberá provenir de la base de datos.

---

# PF-003 — El esquema atlas contiene el negocio.

Toda lógica empresarial reside en funciones del esquema:

atlas

Las integraciones externas nunca ejecutan lógica directamente.

---

# PF-004 — El esquema public expone servicios.

Las aplicaciones externas únicamente consumen funciones públicas.

n8n

↓

public.*

↓

atlas.*

↓

PostgreSQL

Esta separación permite modificar la implementación interna sin afectar las integraciones.

---

# PF-005 — n8n orquesta.

n8n coordina procesos.

No contiene reglas del negocio.

Sus responsabilidades son:

• recibir eventos

• coordinar servicios

• transformar formatos

• ejecutar flujos

Nunca decidir operaciones empresariales.

---

# PF-006 — Existe un único Atlas Payload.

Durante todo el ciclo de vida de un proceso existe un único objeto de negocio.

Cada componente únicamente añade información.

Nunca reemplaza la estructura existente.

Estructura oficial:

{
    conversation,
    client,
    account,
    reservation,
    services,
    metadata
}

El Atlas Payload constituye el contrato oficial entre todos los componentes del sistema.

---

# PF-007 — Cada componente tiene una única responsabilidad.

Toda función, workflow o módulo deberá cumplir una única responsabilidad claramente definida.

Ejemplos:

person()

Crear o recuperar persona.

account()

Crear o recuperar cuenta.

find_or_create_conversation_thread()

Crear o recuperar conversación.

add_conversation_message()

Registrar mensaje.

create_reservation()

Crear reservación.

Esta separación favorece reutilización, pruebas y mantenimiento.

---

# PF-008 — Todo debe ser idempotente.

Siempre que sea posible, ejecutar un proceso dos veces deberá producir el mismo resultado.

Ejemplo:

Una conversación de Outlook nunca deberá duplicarse.

Un cliente existente nunca deberá crearse nuevamente.

Una reservación repetida deberá detectarse mediante reglas de negocio.

---

# PF-009 — La documentación forma parte del software.

Una funcionalidad no se considera terminada hasta que:

• el código funciona;

• las pruebas pasan;

• la documentación refleja el estado actual.

---

# PF-010 — La arquitectura tiene prioridad sobre la velocidad.

Atlas es un proyecto de largo plazo.

Las decisiones temporales que comprometan la arquitectura deberán evitarse.

Cuando exista conflicto entre rapidez y mantenibilidad, prevalecerá la solución arquitectónicamente correcta.

---

## Conclusión

Estos principios representan la base sobre la cual evolucionará Atlas.

Su objetivo es garantizar coherencia, mantenibilidad y escalabilidad conforme el sistema incorpore nuevos módulos, canales e integraciones.
