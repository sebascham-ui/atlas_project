# 7. Gobernanza del Proyecto

## 7.1 Objetivo

La gobernanza define las reglas mediante las cuales Atlas evoluciona.

Su propósito es garantizar que el crecimiento del sistema preserve la coherencia arquitectónica, la calidad técnica y la estabilidad operativa.

Atlas deberá evolucionar mediante decisiones controladas, documentadas y verificables.

---

# 7.2 Principios de Gobernanza

Toda evolución del sistema deberá respetar los siguientes principios:

- La arquitectura tiene prioridad sobre la velocidad.
- Toda decisión importante deberá documentarse.
- Todo cambio deberá ser trazable.
- Todo módulo deberá ser comprobable.
- Todo componente deberá mantener una única responsabilidad.

---

# 7.3 Ciclo Oficial de Desarrollo

Toda funcionalidad seguirá el siguiente proceso:

```text
Idea

↓

Diseño

↓

Implementación

↓

Pruebas

↓

Documentación

↓

Integración

↓

Liberación
```

Ninguna funcionalidad se considera terminada antes de completar todas las etapas.

---

# 7.4 Definición de Terminado (Definition of Done)

Una funcionalidad únicamente podrá considerarse completada cuando:

- la implementación funcione correctamente;
- existan pruebas satisfactorias;
- la documentación se encuentre actualizada;
- el changelog refleje el cambio;
- el Project Master permanezca consistente.

---

# 7.5 Control Arquitectónico

Las siguientes decisiones requieren una revisión explícita antes de implementarse:

- modificación del Atlas Payload;
- modificación del modelo de datos;
- incorporación de nuevos motores;
- eliminación de entidades;
- modificación de contratos públicos;
- incorporación de nuevas tecnologías base.

---

# 7.6 Registro de Decisiones

Toda decisión arquitectónica deberá registrarse mediante un Architecture Decision Record (ADR).

Cada ADR contendrá:

- contexto;
- problema;
- decisión;
- consecuencias;
- estado.

Los ADR constituyen el historial oficial de arquitectura.

---

# 7.7 Versionado

Atlas utilizará Semantic Versioning.

Formato:

MAJOR.MINOR.PATCH

Ejemplo:

0.2.0-alpha

Las versiones principales representan cambios de arquitectura o funcionalidad significativa.

Las versiones menores incorporan nuevas capacidades compatibles.

Las versiones de parche corrigen errores sin modificar contratos.

---

# 7.8 Calidad

Toda entrega deberá preservar:

- consistencia;
- mantenibilidad;
- simplicidad;
- trazabilidad;
- escalabilidad.

---

# 7.9 Filosofía de Evolución

Atlas evolucionará mediante pequeñas mejoras continuas.

Se priorizarán cambios incrementales sobre grandes reescrituras.

La estabilidad del núcleo constituye la principal responsabilidad del proyecto.

---

# 7.10 Regla Fundamental

Toda modificación deberá dejar el sistema en un estado igual o mejor que el encontrado.

La deuda técnica únicamente podrá aceptarse cuando exista una estrategia explícita para eliminarla.

---

## Conclusión

La gobernanza asegura que Atlas pueda evolucionar durante años sin perder coherencia.

La calidad del sistema depende tanto de la disciplina de desarrollo como de la calidad del código.
