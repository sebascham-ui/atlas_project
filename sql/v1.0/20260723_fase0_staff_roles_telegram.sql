-- =====================================================
-- FASE 0 -- Identidad de personal y roles para el bot de Telegram
-- Atlas Project -- 2026-07-23
--
-- Qué hace, en orden:
--   1. Agrega telegram_chat_id a people (para saber quién escribe).
--   2. Crea el catálogo STAFF_ROLE (lavacoches, administrador,
--      contador, asistente de contador) -- el rol de chofer NO
--      necesita catálogo nuevo, ya existe la tabla drivers.
--   3. Crea la tabla staff_roles (una persona puede tener uno o
--      varios roles a lo largo del tiempo, igual que ya hace
--      `contacts` con los roles dentro de una cuenta).
--   4. Generaliza employee_payments agregando person_id, para poder
--      registrar el salario semanal fijo de lavacoches/administración/
--      contador/asistente -- sin tocar el uso actual con driver_id.
--
-- Todo el script es idempotente (se puede correr más de una vez sin
-- duplicar nada ni romper lo que ya existe), siguiendo el mismo
-- patrón que ya usa 20260716_add_message_catalogs.sql.
-- =====================================================

--------------------------------------------------------
-- 1. telegram_chat_id en people
--------------------------------------------------------

ALTER TABLE people
ADD COLUMN IF NOT EXISTS telegram_chat_id character varying UNIQUE;

--------------------------------------------------------
-- 2. Catálogo STAFF_ROLE
--------------------------------------------------------

INSERT INTO catalog_groups(code, name)
SELECT 'STAFF_ROLE', 'Rol de personal (no chofer)'
WHERE NOT EXISTS (
    SELECT 1
    FROM catalog_groups
    WHERE code = 'STAFF_ROLE'
);

INSERT INTO catalog_items(group_id, code, label, sort_order)

SELECT
    g.id,
    v.code,
    v.label,
    v.sort_order

FROM catalog_groups g

CROSS JOIN (

VALUES

('LAVACOCHES', 'Lavacoches', 1),
('ADMINISTRADOR', 'Administrador', 2),
('CONTADOR', 'Contador', 3),
('ASISTENTE_CONTADOR', 'Asistente de Contador', 4)

) v(code, label, sort_order)

WHERE g.code = 'STAFF_ROLE'

AND NOT EXISTS (

    SELECT 1
    FROM catalog_items i
    WHERE i.group_id = g.id
    AND i.code = v.code

);

-- Nos aseguramos de que PERSON_STATUS tenga ACTIVE/INACTIVE, ya que
-- staff_roles.status_id los va a reutilizar (no creamos un catálogo
-- de estatus nuevo solo para esto -- ADS-008).

INSERT INTO catalog_items(group_id, code, label, sort_order)

SELECT
    g.id,
    v.code,
    v.label,
    v.sort_order

FROM catalog_groups g

CROSS JOIN (

VALUES

('ACTIVE', 'Activo', 1),
('INACTIVE', 'Inactivo', 2)

) v(code, label, sort_order)

WHERE g.code = 'PERSON_STATUS'

AND NOT EXISTS (

    SELECT 1
    FROM catalog_items i
    WHERE i.group_id = g.id
    AND i.code = v.code

);

--------------------------------------------------------
-- 3. Tabla staff_roles
--------------------------------------------------------

CREATE TABLE IF NOT EXISTS staff_roles (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    person_id uuid NOT NULL,
    role_type_id integer NOT NULL,
    start_date date NOT NULL DEFAULT CURRENT_DATE,
    end_date date,
    status_id integer NOT NULL,
    notes text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT staff_roles_pkey PRIMARY KEY (id),
    CONSTRAINT fk_staff_roles_person FOREIGN KEY (person_id) REFERENCES people(id),
    CONSTRAINT fk_staff_roles_role_type FOREIGN KEY (role_type_id) REFERENCES catalog_items(id),
    CONSTRAINT fk_staff_roles_status FOREIGN KEY (status_id) REFERENCES catalog_items(id)
);

--------------------------------------------------------
-- 4. Generalizar employee_payments para personal no-chofer
--------------------------------------------------------

ALTER TABLE employee_payments
ADD COLUMN IF NOT EXISTS person_id uuid REFERENCES people(id);

-- driver_id sigue funcionando exactamente igual que hoy para pagos
-- a choferes (por tarifa/servicio). person_id es la vía nueva para
-- salario semanal fijo de lavacoches/administración/contador/
-- asistente -- las dos columnas son opcionales, un pago usa una u
-- otra, nunca ambas.
