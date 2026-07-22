-- =====================================================
-- LIMPIAR DATOS DEL MOTOR DE RESERVACIONES (mantener catálogos y tarifas)
-- Atlas Project -- 2026-07-22
--
-- Para qué sirve: vaciar todo lo que hemos generado probando el motor de
-- reservaciones por correo (clientes, cuentas, hilos, órdenes,
-- servicios, mensajes, notificaciones, y las tablas de choferes/flota
-- que resultaron estar ligadas por llave foránea) para arrancar limpia
-- la recopilación histórica de correos.
--
-- Cómo se llegó a esta lista: el usuario compartió el esquema COMPLETO
-- de Supabase (CREATE TABLE de las 29 tablas con sus foreign keys). Con
-- eso se hizo el análisis completo de dependencias de una sola vez, en
-- vez de ir descubriendo tabla por tabla con cada error de Postgres
-- (que fue como se armó la primera versión de este script). El usuario
-- confirmó en el camino que no existe ningún dato real de operación
-- todavía -- lo único real es lo que construimos juntos en este
-- proyecto (catálogos y las 204 tarifas), que quedan protegidos aparte.
--
-- Las 19 tablas de este vaciado:
--   people, accounts, contacts, service_orders, services, assignments,
--   service_passengers, service_events, conversation_threads,
--   conversation_messages, notifications, expenses, employee_payments,
--   documents, incidents, payments, drivers, vehicle_assignments,
--   vehicle_maintenance
--
-- Por qué "drivers", "vehicle_assignments" y "vehicle_maintenance" están
-- aquí aunque no sean parte del motor de reservaciones: por foreign key
-- directa. "drivers.person_id" apunta a "people" (todo chofer es una
-- persona), así que vaciar "people" exige vaciar "drivers" también.
-- "vehicle_maintenance.workshop_account_id" apunta a "accounts" (el
-- taller es una cuenta), así que vaciar "accounts" exige vaciar
-- "vehicle_maintenance". Y "vehicle_assignments.driver_id" apunta a
-- "drivers", así que al vaciar "drivers" también hay que vaciar
-- "vehicle_assignments". El usuario confirmó que estas tres están
-- vacías o solo con datos de prueba, así que no hay riesgo real.
--
-- Esto NO toca (ni debe tocar) -- confirmado por el esquema que no
-- dependen de ninguna tabla de arriba: organizations, vehicles,
-- vehicle_types, expense_categories, audit_log, system_settings,
-- operation_fields, catalog_groups, catalog_items, pricing_rates.
--
-- IMPORTANTE: vaciar una tabla con TRUNCATE nunca borra su estructura,
-- columnas, ni las relaciones (foreign keys) con otras tablas -- eso se
-- queda igual para siempre. Solo se borra el contenido (las filas).
--
-- Nota técnica: este TRUNCATE no usa CASCADE -- se construyó la lista
-- completa a mano para que incluya exactamente las tablas necesarias,
-- así Postgres no tiene que adivinar ni arrastrar nada por su cuenta.
-- Si aun así sale un error de dependencia (señal de que el análisis
-- pasó por alto algo), copia el mensaje completo antes de agregar
-- CASCADE a la fuerza -- lo revisamos juntos primero.
-- =====================================================

TRUNCATE TABLE
    conversation_messages,
    notifications,
    service_events,
    service_passengers,
    services,
    service_orders,
    conversation_threads,
    contacts,
    accounts,
    people,
    assignments,
    expenses,
    employee_payments,
    documents,
    incidents,
    payments,
    drivers,
    vehicle_assignments,
    vehicle_maintenance
;
