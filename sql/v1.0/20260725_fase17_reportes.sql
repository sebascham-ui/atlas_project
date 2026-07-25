-- =====================================================
-- FASE 17 -- Reportes para el menú de Admin (solo lectura)
-- Atlas Project -- 2026-07-25
--
-- Todas estas funciones SOLO LEEN datos, no modifican nada -- por eso son
-- de bajo riesgo. Alimentan el menú "Reportes" del bot de admin.
--
--   1) report_services(p_scope)    -- servicios de hoy / mañana / semana
--   2) report_income()             -- ingresos (hoy / semana / mes)
--   3) report_expenses()           -- gastos (hoy / semana / mes + por categoría)
--   4) report_trips_by_driver()    -- viajes por chofer (esta semana)
--   5) report_incidents()          -- incidentes de los últimos 7 días
--
-- Nota sobre ingresos: se suma services.quoted_price (el precio cotizado
-- de cada servicio). Si esa columna todavía no se está llenando al crear
-- reservaciones, los ingresos saldrán en $0 -- es un tema de que el motor
-- de precios se conecte al alta, no de este reporte.
--
-- Requiere: esquema base (services, expenses, incidents, assignments...).
-- =====================================================

--------------------------------------------------------
-- 1) report_services(p_scope) -- 'today' | 'tomorrow' | 'week'
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.report_services(p_scope text)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
WITH params AS (
  SELECT (now() AT TIME ZONE 'America/Mexico_City')::date AS today
),
rango AS (
  SELECT
    CASE p_scope WHEN 'tomorrow' THEN today + 1 ELSE today END AS d_from,
    CASE p_scope
      WHEN 'today' THEN today
      WHEN 'tomorrow' THEN today + 1
      WHEN 'week' THEN today + 7
      ELSE today END AS d_to
  FROM params
),
rows AS (
  SELECT
    s.id, s.scheduled_departure,
    to_char(s.scheduled_departure AT TIME ZONE 'America/Mexico_City', 'DD/MM') AS fecha_txt,
    to_char(s.scheduled_departure AT TIME ZONE 'America/Mexico_City', 'HH24:MI') AS hora_txt,
    (CASE extract(isodow FROM (s.scheduled_departure AT TIME ZONE 'America/Mexico_City'))
       WHEN 1 THEN 'lun' WHEN 2 THEN 'mar' WHEN 3 THEN 'mie' WHEN 4 THEN 'jue'
       WHEN 5 THEN 'vie' WHEN 6 THEN 'sab' WHEN 7 THEN 'dom' END) AS weekday,
    s.origin, s.destination, s.flight_number,
    COALESCE(sp.passenger_name, pp.given_names || COALESCE(' ' || pp.last_name, ''),
             org.commercial_name, org.legal_name, '(sin nombre)') AS client_name,
    dp.given_names || COALESCE(' ' || dp.last_name, '') AS driver_name,
    v.internal_code AS vehicle_code
  FROM services s
  JOIN service_orders so ON so.id = s.service_order_id
  JOIN accounts acc ON acc.id = so.account_id
  LEFT JOIN people pp ON pp.id = acc.person_id
  LEFT JOIN organizations org ON org.id = acc.organization_id
  LEFT JOIN service_passengers sp ON sp.service_id = s.id AND sp.is_primary_contact = true
  LEFT JOIN catalog_items st ON st.id = s.status_id
  LEFT JOIN LATERAL (
      SELECT a.driver_id, a.vehicle_id FROM assignments a WHERE a.service_id = s.id
      ORDER BY a.created_at DESC LIMIT 1) asg ON true
  LEFT JOIN drivers drv ON drv.id = asg.driver_id
  LEFT JOIN people dp ON dp.id = drv.person_id
  LEFT JOIN vehicles v ON v.id = asg.vehicle_id
  WHERE s.scheduled_departure IS NOT NULL
    AND COALESCE(st.code, '') <> 'CANCELLED'
    AND (s.scheduled_departure AT TIME ZONE 'America/Mexico_City')::date
        BETWEEN (SELECT d_from FROM rango) AND (SELECT d_to FROM rango)
  ORDER BY s.scheduled_departure
)
SELECT jsonb_build_object(
  'scope', p_scope,
  'count', (SELECT count(*) FROM rows),
  'services', COALESCE((SELECT jsonb_agg(jsonb_build_object(
      'fecha_txt', r.fecha_txt, 'hora_txt', r.hora_txt, 'weekday', r.weekday,
      'origin', r.origin, 'destination', r.destination, 'client_name', r.client_name,
      'flight_number', r.flight_number, 'driver_name', r.driver_name, 'vehicle_code', r.vehicle_code)
      ORDER BY r.scheduled_departure) FROM rows r), '[]'::jsonb));
$function$;

CREATE OR REPLACE FUNCTION public.report_services(p_scope text)
RETURNS jsonb LANGUAGE sql AS $function$ SELECT atlas.report_services(p_scope); $function$;


--------------------------------------------------------
-- 2) report_income() -- suma de quoted_price por periodo (hoy/semana/mes)
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.report_income()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
WITH params AS (SELECT (now() AT TIME ZONE 'America/Mexico_City')::date AS today),
d AS (
  SELECT s.quoted_price,
    (s.scheduled_departure AT TIME ZONE 'America/Mexico_City')::date AS ld
  FROM services s
  LEFT JOIN catalog_items st ON st.id = s.status_id
  WHERE s.scheduled_departure IS NOT NULL AND COALESCE(st.code,'') <> 'CANCELLED'
)
SELECT jsonb_build_object(
  'hoy',    COALESCE((SELECT sum(quoted_price) FROM d, params WHERE ld = today), 0),
  'semana', COALESCE((SELECT sum(quoted_price) FROM d, params
                      WHERE ld >= date_trunc('week', today::timestamp)::date
                        AND ld <  date_trunc('week', today::timestamp)::date + 7), 0),
  'mes',    COALESCE((SELECT sum(quoted_price) FROM d, params
                      WHERE ld >= date_trunc('month', today::timestamp)::date
                        AND ld <  (date_trunc('month', today::timestamp) + interval '1 month')::date), 0)
);
$function$;

CREATE OR REPLACE FUNCTION public.report_income()
RETURNS jsonb LANGUAGE sql AS $function$ SELECT atlas.report_income(); $function$;


--------------------------------------------------------
-- 3) report_expenses() -- gastos por periodo + desglose del mes por categoría
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.report_expenses()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
WITH params AS (SELECT (now() AT TIME ZONE 'America/Mexico_City')::date AS today),
e AS (
  SELECT ex.amount, ec.name AS categoria,
    (ex.expense_datetime AT TIME ZONE 'America/Mexico_City')::date AS ld
  FROM expenses ex
  JOIN expense_categories ec ON ec.id = ex.expense_category_id
)
SELECT jsonb_build_object(
  'hoy',    COALESCE((SELECT sum(amount) FROM e, params WHERE ld = today), 0),
  'semana', COALESCE((SELECT sum(amount) FROM e, params
                      WHERE ld >= date_trunc('week', today::timestamp)::date
                        AND ld <  date_trunc('week', today::timestamp)::date + 7), 0),
  'mes',    COALESCE((SELECT sum(amount) FROM e, params
                      WHERE ld >= date_trunc('month', today::timestamp)::date
                        AND ld <  (date_trunc('month', today::timestamp) + interval '1 month')::date), 0),
  'mes_por_categoria', COALESCE((
     SELECT jsonb_agg(jsonb_build_object('categoria', categoria, 'total', total) ORDER BY total DESC)
     FROM (
       SELECT categoria, sum(amount) AS total
       FROM e, params
       WHERE ld >= date_trunc('month', today::timestamp)::date
         AND ld <  (date_trunc('month', today::timestamp) + interval '1 month')::date
       GROUP BY categoria
     ) q), '[]'::jsonb));
$function$;

CREATE OR REPLACE FUNCTION public.report_expenses()
RETURNS jsonb LANGUAGE sql AS $function$ SELECT atlas.report_expenses(); $function$;


--------------------------------------------------------
-- 4) report_trips_by_driver() -- viajes por chofer, esta semana
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.report_trips_by_driver()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
WITH params AS (SELECT (now() AT TIME ZONE 'America/Mexico_City')::date AS today),
asignados AS (
  SELECT DISTINCT ON (s.id)
    s.id AS service_id, s.destination,
    (s.scheduled_departure AT TIME ZONE 'America/Mexico_City')::date AS ld,
    a.driver_id
  FROM services s
  JOIN assignments a ON a.service_id = s.id
  LEFT JOIN catalog_items st ON st.id = s.status_id
  WHERE a.driver_id IS NOT NULL
    AND s.scheduled_departure IS NOT NULL
    AND COALESCE(st.code,'') <> 'CANCELLED'
  ORDER BY s.id, a.created_at DESC
),
en_semana AS (
  SELECT a.*, dp.given_names || COALESCE(' ' || dp.last_name, '') AS driver_name
  FROM asignados a
  JOIN drivers drv ON drv.id = a.driver_id
  JOIN people dp ON dp.id = drv.person_id, params
  WHERE a.ld >= date_trunc('week', today::timestamp)::date
    AND a.ld <  date_trunc('week', today::timestamp)::date + 7
)
SELECT jsonb_build_object('drivers', COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
     'driver_name', driver_name, 'trip_count', trip_count, 'destinations', destinations)
     ORDER BY trip_count DESC)
  FROM (
    SELECT driver_name, count(*) AS trip_count,
           jsonb_agg(DISTINCT destination) FILTER (WHERE destination IS NOT NULL) AS destinations
    FROM en_semana GROUP BY driver_name
  ) q), '[]'::jsonb));
$function$;

CREATE OR REPLACE FUNCTION public.report_trips_by_driver()
RETURNS jsonb LANGUAGE sql AS $function$ SELECT atlas.report_trips_by_driver(); $function$;


--------------------------------------------------------
-- 5) report_incidents() -- incidentes de los últimos 7 días
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.report_incidents()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
SELECT jsonb_build_object('incidents', COALESCE((
  SELECT jsonb_agg(jsonb_build_object(
     'fecha_txt', to_char(i.incident_datetime AT TIME ZONE 'America/Mexico_City', 'DD/MM HH24:MI'),
     'tipo', ti.label, 'severidad', sev.label,
     'descripcion', i.description, 'vehicle_code', v.internal_code)
     ORDER BY i.incident_datetime DESC)
  FROM incidents i
  LEFT JOIN catalog_items ti ON ti.id = i.incident_type_id
  LEFT JOIN catalog_items sev ON sev.id = i.severity_id
  LEFT JOIN vehicles v ON v.id = i.vehicle_id
  WHERE i.incident_datetime >= now() - interval '7 days'
), '[]'::jsonb));
$function$;

CREATE OR REPLACE FUNCTION public.report_incidents()
RETURNS jsonb LANGUAGE sql AS $function$ SELECT atlas.report_incidents(); $function$;
