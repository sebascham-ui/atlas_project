# 3. Arquitectura del Sistema

## 3.1 Objetivo

La arquitectura de Atlas está diseñada para separar claramente las responsabilidades de interpretación, orquestación, lógica de negocio y persistencia.

Cada componente tiene una responsabilidad única y se comunica mediante contratos bien definidos.

Esta separación permite evolucionar el sistema sin afectar componentes independientes.

---

# 3.2 Arquitectura General

```

```
                    CANALES DE ENTRADA

        Outlook      WhatsApp      Portal Web
             \            |             /
              \           |            /
               +----------------------+
               |        n8n           |
               +----------------------+
                          |
                          |
                 OpenAI (Interpretación)
                          |
                          |
                 Atlas Payload (Único)
                          |
                          |
              +-------------------------+
              |     RPC públicas         |
              |       public.*           |
              +-------------------------+
                          |
                          |
              +-------------------------+
              |    Motor Atlas          |
              |      schema atlas       |
              +-------------------------+
                          |
                          |
                 PostgreSQL / Supabase
                          |
                          |
                  Fuente única de verdad
```

---

# 3.3 Componentes

## Canales de Entrada

Los canales representan el punto de contacto entre Atlas y el exterior.

Actualmente:

- Microsoft Outlook

Planeados:

- Gmail
- WhatsApp Business
- Telegram
- Portal Web
- Aplicación móvil
- API pública

Todos los canales deberán converger hacia el mismo flujo de procesamiento.

---

## n8n

n8n constituye el motor de orquestación.

Sus responsabilidades incluyen:

- recibir eventos externos;
- coordinar procesos;
- ejecutar flujos;
- transformar formatos;
- consumir servicios externos.

n8n no implementa reglas de negocio.

---

## OpenAI

OpenAI constituye el motor de interpretación.

Responsabilidades:

- comprensión del lenguaje natural;
- extracción de entidades;
- clasificación de solicitudes;
- generación de borradores;
- asistencia conversacional.

OpenAI no modifica directamente la base de datos.

---

## Atlas Payload

El Atlas Payload constituye el contrato oficial del sistema.

Toda información procesada deberá representarse mediante esta estructura.

Cada etapa únicamente enriquece el payload existente.

Nunca se generan contratos alternativos.

---

## RPC Públicas

Las funciones del esquema public representan la interfaz oficial del motor Atlas.

Toda integración externa deberá consumir exclusivamente estas funciones.

Esto desacopla los clientes de la implementación interna.

---

## Motor Atlas

El esquema atlas concentra toda la lógica de negocio.

Ejemplos:

- gestión de personas;
- cuentas;
- conversaciones;
- reservaciones;
- servicios;
- operaciones futuras.

El motor Atlas constituye el núcleo del sistema.

---

## PostgreSQL

PostgreSQL es la fuente única de verdad.

Toda operación persistente finaliza en la base de datos.

Ningún otro componente mantiene estado operativo permanente.

---

# 3.4 Flujo General

El procesamiento estándar sigue las siguientes etapas:

1. Recepción del evento.
2. Interpretación mediante IA.
3. Construcción del Atlas Payload.
4. Enriquecimiento progresivo del payload.
5. Ejecución de reglas de negocio.
6. Persistencia.
7. Generación de respuesta.

Este patrón será común para cualquier canal de entrada.

---

# 3.5 Desacoplamiento

La arquitectura busca minimizar dependencias entre componentes.

Ejemplos:

- cambiar OpenAI por otro proveedor no modifica Atlas;
- cambiar Outlook por Gmail no modifica el motor de negocio;
- cambiar n8n por otro orquestador no modifica PostgreSQL.

Los contratos entre componentes permanecen estables.

---

# 3.6 Escalabilidad

Atlas ha sido diseñado para crecer horizontalmente.

Nuevos módulos deberán integrarse mediante:

- nuevos canales;
- nuevos motores;
- nuevas funciones;
- nuevos enriquecimientos del Atlas Payload.

La arquitectura evita dependencias circulares y favorece la reutilización de componentes.

---

## Conclusión

Atlas implementa una arquitectura modular basada en responsabilidades claramente separadas.

Esta organización permite mantener estabilidad en el núcleo del sistema mientras evolucionan los canales, las automatizaciones y las capacidades de inteligencia artificial.
