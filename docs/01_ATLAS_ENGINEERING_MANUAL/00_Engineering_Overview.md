# Atlas Engineering Manual

## Introducción

El Atlas Engineering Manual define los estándares técnicos utilizados durante el desarrollo del sistema Atlas.

Su propósito es garantizar consistencia, mantenibilidad y escalabilidad a lo largo de toda la vida del proyecto.

Mientras el Atlas Project Master responde:

> ¿Qué es Atlas?

Este manual responde:

> ¿Cómo se construye Atlas?

---

# Alcance

Este manual define estándares para:

- SQL
- PostgreSQL
- Supabase
- RPC públicas
- n8n
- OpenAI
- Atlas Payload
- Diagramas
- Testing
- Git
- Releases

---

# Principio General

Todo componente nuevo deberá seguir los estándares definidos en este manual.

Cuando una implementación entre en conflicto con estos estándares, deberá justificarse mediante un Architecture Decision Record (ADR).

---

# Filosofía

Atlas prioriza:

- claridad;
- simplicidad;
- modularidad;
- desacoplamiento;
- documentación;
- pruebas.

El objetivo no consiste únicamente en producir software funcional.

El objetivo consiste en producir software mantenible durante muchos años.

---

# Organización

Este manual se divide en los siguientes capítulos:

01_SQL_Standards.md

02_RPC_Standards.md

03_n8n_Standards.md

04_OpenAI_Standards.md

05_Atlas_Payload_Standards.md

06_Diagram_Standards.md

07_Testing_Standards.md

08_Git_Standards.md

09_Release_Process.md

Cada capítulo podrá evolucionar independientemente del resto.

---

# Regla Fundamental

Ningún estándar existe por costumbre.

Todo estándar deberá responder a un problema real del proyecto.

Si un estándar deja de aportar valor, deberá revisarse mediante el proceso de gobernanza definido en el Atlas Project Master.
