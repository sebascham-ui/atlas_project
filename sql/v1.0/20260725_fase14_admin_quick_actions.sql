-- =====================================================
-- FASE 14 -- Acciones Rápidas del menú de Administración (bot de Telegram)
-- Atlas Project -- 2026-07-25
--
-- Para qué sirve: el bot de Admin ya sabe crear una reservación nueva
-- (Registrar reservación -> create_service_order/add_service), pero no
-- tenía forma de: ver qué servicios hay programados un día dado, ni
-- asignarles chofer o unidad. Esta migración agrega exactamente eso --
-- nada de "modificar/cancelar servicio" ni las demás categorías del
-- módulo administrativo completo, eso queda para fases futuras a
-- propósito (ver plan de Fase 1 de Acciones Rápidas).
--
-- Reutiliza tablas que YA EXISTEN y ya estaban diseñadas para esto
-- (services, assignments, drivers) -- no se crea ninguna tabla nueva.
--
-- Requiere haber corrido antes:
--   sql/migrations/20260724_fase3_catalogos_reservaciones.sql (SERVICE_STATUS)
--   sql/migrations/20260724_fase9_unidades_en_bot.sql (atlas.resolve_vehicle_id)
--   sql/v1.0/staff_identity_v1.sql (PERSON_STATUS ya se usa en drivers.status_id)
-- =====================================================


--------------------------------------------------------
-- 0) Catálogos nuevos que hacían falta
--------------------------------------------------------

-- SERVICE_STATUS ya existe (fase 3) con un solo código, 'RECEIVED'.
-- Se agrega 'ASSIGNED' -- se pone cuando un servicio ya tiene chofer
-- y/o unidad asignados. No se toca 'RECEIVED'.
INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('ASSIGNED', 'Asignado', 2)
) v(code, label, sort_order)
WHERE g.code = 'SERVICE_STATUS'
AND NOT EXISTS (SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code);

-- ASSIGNMENT_STATUS es un grupo nuevo -- assignments.status_id ya
-- existía en el esquema pero ninguna función lo usaba todavía. Por
-- ahora un solo código, ACTIVE (la asignación vigente de un servicio).
-- Cuando exista "reasignar" o "cancelar asignación" se agregan más
-- códigos ahí, no aquí.
INSERT INTO catalog_groups(code, name)
SELECT 'ASSIGNMENT_STATUS', 'Estado de la Asignación'
WHERE NOT EXISTS (SELECT 1 FROM catalog_groups WHERE code = 'ASSIGNMENT_STATUS');

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('ACTIVE', 'Activa', 1)
) v(code, label, sort_order)
WHERE g.code = 'ASSIGNMENT_STATUS'
AND NOT EXISTS (SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code);


--------------------------------------------------------
-- 1) atlas.list_services_for_date(p_date) -- para "Servicios de mañana"
--    y como base de las listas de "Asignar chofer/unidad" (el bot
--    filtra en el flujo cuáles no tienen chofer/unidad todavía).
--
--    El nombre del cliente sale del pasajero principal del servicio si
--    existe (service_passengers.is_primary_contact), y si no, de la
--    cuenta (persona u organización) -- así siempre hay algo que
--    mostrarle al admin, sin inventar datos.
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.list_services_for_date(p_date date)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  SELECT jsonb_build_object('services', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', s.id,
        'scheduled_time', to_char(s.scheduled_departure AT TIME ZONE 'America/Mexico_City', 'HH24:MI'),
        'origin', s.origin,
        'destination', s.destination,
        'client_name', COALESCE(sp.passenger_name, pp.given_names || COALESCE(' ' || pp.last_name, ''), org.commercial_name, org.legal_name, '(sin nombre)'),
        'driver_name', dp.given_names || COALESCE(' ' || dp.last_name, ''),
        'vehicle_code', v.internal_code,
        'status_code', st.code
      )
      ORDER BY s.scheduled_departure NULLS LAST
  ), '[]'::jsonb))
  FROM services s
  JOIN service_orders so ON so.id = s.service_order_id
  JOIN accounts acc ON acc.id = so.account_id
  LEFT JOIN people pp ON pp.id = acc.person_id
  LEFT JOIN organizations org ON org.id = acc.organization_id
  LEFT JOIN service_passengers sp ON sp.service_id = s.id AND sp.is_primary_contact = true
  LEFT JOIN catalog_items st ON st.id = s.status_id
  LEFT JOIN LATERAL (
      SELECT a.driver_id, a.vehicle_id
      FROM assignments a
      WHERE a.service_id = s.id
      ORDER BY a.created_at DESC
      LIMIT 1
  ) asg ON true
  LEFT JOIN drivers drv ON drv.id = asg.driver_id
  LEFT JOIN people dp ON dp.id = drv.person_id
  LEFT JOIN vehicles v ON v.id = asg.vehicle_id
  WHERE (s.scheduled_departure AT TIME ZONE 'America/Mexico_City')::date = p_date;
$function$;

CREATE OR REPLACE FUNCTION public.list_services_for_date(p_date date)
RETURNS jsonb
LANGUAGE sql
AS $function$
SELECT atlas.list_services_for_date(p_date);
$function$;


--------------------------------------------------------
-- 2) atlas.list_active_drivers() -- simétrica a list_active_vehicles
--    (fase 9). Se usa 'id' (UUID) como identificador para que el bot lo
--    mande de regreso en el botón (callback_data), en vez de hacer
--    match de texto como con las unidades -- así se evita por completo
--    la clase de bug que ya tuvimos con "3/4" en combustible (ver Ronda
--    21): un chofer sin employee_code no se queda fuera de la lista.
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.list_active_drivers()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  SELECT jsonb_build_object('drivers', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'label', p.given_names || COALESCE(' ' || p.last_name, '') ||
                 CASE WHEN d.employee_code IS NOT NULL THEN ' (' || d.employee_code || ')' ELSE '' END
      )
      ORDER BY p.given_names
  ), '[]'::jsonb))
  FROM drivers d
  JOIN people p ON p.id = d.person_id
  JOIN catalog_items st ON st.id = d.status_id
  JOIN catalog_groups sg ON sg.id = st.group_id
  WHERE sg.code = 'PERSON_STATUS' AND st.code = 'ACTIVE';
$function$;

CREATE OR REPLACE FUNCTION public.list_active_drivers()
RETURNS jsonb
LANGUAGE sql
AS $function$
SELECT atlas.list_active_drivers();
$function$;


--------------------------------------------------------
-- 3) atlas.assign_service -- asigna chofer y/o unidad a un servicio ya
--    existente. Acepta uno solo, otro solo, o ambos (NULL = "no tocar
--    este dato"), para que "Asignar chofer" y "Asignar unidad" del bot
--    puedan llamar la misma función sin pisarse el uno al otro.
--
--    Si el servicio ya tenía una asignación (por ejemplo se le puso
--    chofer antes y ahora se le pone la unidad), se actualiza la misma
--    fila en vez de crear otra -- un servicio tiene una sola asignación
--    vigente.
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.assign_service(
    p_service_id uuid,
    p_driver_id uuid DEFAULT NULL,
    p_vehicle_id uuid DEFAULT NULL,
    p_assigned_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    v_assignment_id UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM services WHERE id = p_service_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'no existe ese servicio');
    END IF;

    IF p_driver_id IS NULL AND p_vehicle_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'se requiere chofer y/o unidad');
    END IF;

    SELECT id INTO v_assignment_id
    FROM assignments
    WHERE service_id = p_service_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_assignment_id IS NOT NULL THEN
        UPDATE assignments
        SET driver_id = COALESCE(p_driver_id, driver_id),
            vehicle_id = COALESCE(p_vehicle_id, vehicle_id),
            assigned_by = COALESCE(p_assigned_by, assigned_by),
            updated_at = now()
        WHERE id = v_assignment_id;
    ELSE
        INSERT INTO assignments(service_id, driver_id, vehicle_id, assigned_by, status_id)
        VALUES(p_service_id, p_driver_id, p_vehicle_id, p_assigned_by, atlas.catalog('ASSIGNMENT_STATUS', 'ACTIVE'))
        RETURNING id INTO v_assignment_id;
    END IF;

    UPDATE services
    SET status_id = atlas.catalog('SERVICE_STATUS', 'ASSIGNED'), updated_at = now()
    WHERE id = p_service_id;

    RETURN jsonb_build_object('success', true, 'assignment_id', v_assignment_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.assign_service(
    p_service_id uuid,
    p_driver_id uuid DEFAULT NULL,
    p_vehicle_id uuid DEFAULT NULL,
    p_assigned_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
AS $function$
SELECT atlas.assign_service(p_service_id, p_driver_id, p_vehicle_id, p_assigned_by);
$function$;
