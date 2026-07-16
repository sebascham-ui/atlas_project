# 4. Modelo de Dominio

## 4.1 Introducción

Atlas se construye alrededor de conceptos del negocio, no alrededor de tablas, APIs o tecnologías.

Toda implementación técnica debe representar fielmente el dominio operativo de la empresa.

Este capítulo define el lenguaje oficial del sistema y establece el significado de cada concepto principal.

---

# 4.2 Conversación

Una conversación representa la relación continua entre Atlas y un cliente a través de uno o varios canales de comunicación.

Una conversación existe independientemente de:

- una reservación;
- una cotización;
- una orden de servicio;
- un canal específico.

Puede comenzar mediante un correo electrónico, continuar por WhatsApp y finalizar mediante una llamada telefónica.

La conversación constituye el contexto principal de interacción.

---

# 4.3 Mensaje

Un mensaje representa un evento individual dentro de una conversación.

Puede ser:

- recibido;
- enviado;
- generado por IA;
- generado por un operador.

Todo mensaje pertenece exactamente a una conversación.

Una conversación puede contener un número ilimitado de mensajes.

---

# 4.4 Persona

Una persona representa a un individuo.

La persona existe independientemente de:

- cuentas;
- empresas;
- reservaciones.

Una misma persona puede participar en múltiples conversaciones y múltiples operaciones.

La persona constituye la identidad humana del sistema.

---

# 4.5 Cuenta

La cuenta representa la relación comercial entre Atlas y un cliente.

Puede corresponder a:

- una persona física;
- una empresa;
- una agencia;
- un convenio.

Una cuenta agrupa operaciones.

No representa necesariamente a una persona.

---

# 4.6 Orden de Servicio

La orden de servicio representa un compromiso operativo.

Toda ejecución logística se organiza mediante órdenes de servicio.

Una orden puede contener uno o varios servicios.

La orden constituye la unidad principal de operación.

---

# 4.7 Servicio

El servicio representa una actividad específica que deberá ejecutarse.

Ejemplos:

- traslado aeropuerto → hotel;
- traslado hotel → aeropuerto;
- disposición por horas;
- viaje especial.

Cada servicio pertenece exactamente a una orden.

---

# 4.8 Canal

El canal representa el medio mediante el cual ocurre una interacción.

Ejemplos:

- Outlook
- Gmail
- WhatsApp
- Telegram
- Portal Web
- Aplicación móvil

Los canales pertenecen a los mensajes.

Las conversaciones pueden extenderse entre múltiples canales.

---

# 4.9 Atlas Payload

El Atlas Payload representa el estado completo del proceso de negocio durante una ejecución.

No constituye una entidad persistente.

Es un contrato temporal entre componentes.

Su propósito es transportar contexto de forma consistente.

---

# 4.10 Contexto

El contexto representa toda la información necesaria para comprender correctamente una situación operativa.

El contexto puede construirse a partir de:

- conversaciones anteriores;
- clientes;
- órdenes;
- mensajes;
- historial;
- preferencias;
- reglas del negocio.

La construcción del contexto constituye el objetivo principal de Atlas.

---

# 4.11 Inteligencia Operativa

La inteligencia operativa consiste en utilizar el contexto acumulado para asistir a las personas en la toma de decisiones.

Atlas no busca sustituir operadores.

Busca proporcionar mejores herramientas para decidir.

---

# 4.12 Lenguaje Ubicuo

Todo desarrollo futuro deberá utilizar la terminología definida en este capítulo.

No deberán introducirse sinónimos innecesarios.

Por ejemplo:

✓ Conversación

✗ Chat

✗ Hilo

✗ Ticket

✓ Orden de Servicio

✗ Reserva

✗ Viaje

✗ Servicio Principal

La consistencia terminológica facilita el desarrollo, la documentación y la comunicación entre los participantes del proyecto.

---

## Conclusión

Atlas se modela alrededor de conceptos del negocio.

Las tablas, funciones y tecnologías son únicamente implementaciones de estos conceptos.

La estabilidad del dominio garantiza la evolución sostenible del sistema.
