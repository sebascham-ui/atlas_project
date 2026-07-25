-- =====================================================
-- FASE 15 -- Buscar cualquier viaje futuro para asignar chofer/unidad
-- Atlas Project -- 2026-07-25
--
-- Para qué sirve: hasta ahora "Asignar chofer/unidad" solo mostraba los
-- servicios de MAÑANA sin asignar. Sebastián pidió poder asignar a
-- cualquier viaje futuro, identificándolo con un dato parcial (nombre del
-- cliente, horario, origen/destino, número de vuelo o fecha), y que la
-- vista por defecto sea SEMANAL en vez de solo mañana.
--
-- Esta función cubre las dos cosas con un solo lugar:
--   - p_query vacío  -> los pendientes de ESTA SEMANA (hoy .. +7 días) que
--     todavía no tienen chofer (p_mode='chofer') o unidad (p_mode='unidad').
--   - p_query con texto -> CUALQUIER viaje futuro (de hoy en adelante, sin
--     límite de semana) cuyo "texto identificador" contenga lo que se
--     escribió. El texto identificador junta: nombre del cliente, origen,
--     destino, número de vuelo, fecha (DD/MM), día de la semana y mes en
--     español -- así el admin puede escribir "Laura", "aeropuerto",
--     "15/08", "vie", "agosto" o "AM123" y lo encuentra. La búsqueda ignora
--     mayúsculas y acentos (translate).
--
-- En el modo búsqueda NO se filtran los ya asignados: se muestran todos con
-- su estado actual (quién tiene asignado), para poder reasignar a
-- conciencia. assign_service (Fase 14) sobre-escribe la asignación si se
-- elige un chofer/unidad nuevo.
--
-- No reemplaza list_services_for_date (Fase 14), que sigue usándose para
-- "Servicios de mañana". Esta es aparte, solo para el asignador.
--
-- Requiere haber corrido antes:
--   sql/migrations/20260725_fase14_admin_quick_actions.sql
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.find_services_to_assign(p_query text, p_mode text)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
WITH enriched AS (
  SELECT
    s.id,
    s.scheduled_departure,
    (s.scheduled_departure AT TIME ZONE 'America/Mexico_City')::date AS local_date,
    s.origin,
    s.destination,
    s.flight_number,
    to_char(s.scheduled_departure AT TIME ZONE 'America/Mexico_City', 'DD/MM') AS fecha_txt,
    to_char(s.scheduled_departure AT TIME ZONE 'America/Mexico_City', 'HH24:MI') AS hora_txt,
    (CASE extract(isodow FROM (s.scheduled_departure AT TIME ZONE 'America/Mexico_City'))
       WHEN 1 THEN 'lun' WHEN 2 THEN 'mar' WHEN 3 THEN 'mie' WHEN 4 THEN 'jue'
       WHEN 5 THEN 'vie' WHEN 6 THEN 'sab' WHEN 7 THEN 'dom' END) AS weekday,
    (CASE extract(month FROM (s.scheduled_departure AT TIME ZONE 'America/Mexico_City'))
       WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo' WHEN 4 THEN 'abril'
       WHEN 5 THEN 'mayo' WHEN 6 THEN 'junio' WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto'
       WHEN 9 THEN 'septiembre' WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre'
       WHEN 12 THEN 'diciembre' END) AS mes_txt,
    COALESCE(sp.passenger_name,
             pp.given_names || COALESCE(' ' || pp.last_name, ''),
             org.commercial_name, org.legal_name, '(sin nombre)') AS client_name,
    dp.given_names || COALESCE(' ' || dp.last_name, '') AS driver_name,
    v.internal_code AS vehicle_code
  FROM services s
  JOIN service_orders so ON so.id = s.service_order_id
  JOIN accounts acc ON acc.id = so.account_id
  LEFT JOIN people pp ON pp.id = acc.person_id
  LEFT JOIN organizations org ON org.id = acc.organization_id
  LEFT JOIN service_passengers sp ON sp.service_id = s.id AND sp.is_primary_contact = true
  LEFT JOIN LATERAL (
      SELECT a.driver_id, a.vehicle_id
      FROM assignments a WHERE a.service_id = s.id
      ORDER BY a.created_at DESC LIMIT 1
  ) asg ON true
  LEFT JOIN drivers drv ON drv.id = asg.driver_id
  LEFT JOIN people dp ON dp.id = drv.person_id
  LEFT JOIN vehicles v ON v.id = asg.vehicle_id
  WHERE s.scheduled_departure IS NOT NULL
),
picked AS (
  SELECT e.*
  FROM enriched e
  WHERE e.local_date >= (now() AT TIME ZONE 'America/Mexico_City')::date
    AND (
      -- Vista por defecto (sin búsqueda): pendientes de esta semana
      ( NULLIF(trim(coalesce(p_query, '')), '') IS NULL
        AND e.local_date <= (now() AT TIME ZONE 'America/Mexico_City')::date + 7
        AND ( (p_mode = 'chofer' AND e.driver_name IS NULL)
           OR (p_mode = 'unidad' AND e.vehicle_code IS NULL) )
      )
      OR
      -- Búsqueda: cualquier viaje futuro que contenga el texto
      ( NULLIF(trim(coalesce(p_query, '')), '') IS NOT NULL
        AND translate(lower(concat_ws(' ', e.client_name, e.origin, e.destination,
                                      e.flight_number, e.fecha_txt, e.weekday, e.mes_txt)),
                      'áéíóúñ', 'aeioun')
            LIKE '%' || translate(lower(trim(p_query)), 'áéíóúñ', 'aeioun') || '%'
      )
    )
  ORDER BY e.scheduled_departure
  LIMIT 25
)
SELECT jsonb_build_object('services', COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'fecha_txt', p.fecha_txt,
      'hora_txt', p.hora_txt,
      'weekday', p.weekday,
      'origin', p.origin,
      'destination', p.destination,
      'client_name', p.client_name,
      'flight_number', p.flight_number,
      'driver_name', p.driver_name,
      'vehicle_code', p.vehicle_code
    ) ORDER BY p.scheduled_departure), '[]'::jsonb))
FROM picked p;
$function$;

CREATE OR REPLACE FUNCTION public.find_services_to_assign(p_query text, p_mode text)
RETURNS jsonb
LANGUAGE sql
AS $function$
SELECT atlas.find_services_to_assign(p_query, p_mode);
$function$;
