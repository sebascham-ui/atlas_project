-- =====================================================
-- FASE 16 -- Gestión de servicios desde el bot de Admin
-- Atlas Project -- 2026-07-25
--
-- Para qué sirve: el menú "Servicios" del admin necesita poder buscar
-- cualquier viaje futuro, cancelarlo, y modificar sus datos (horario,
-- origen, destino, pasajeros, maletas, vuelo, nota). Las tablas ya
-- existen (services); esto agrega las funciones que faltaban.
--
-- Contenido:
--   0) Catálogo SERVICE_STATUS += 'CANCELLED'.
--   1) find_future_services(p_query) -- buscador general de viajes futuros
--      (para elegir cuál modificar/cancelar). Sin filtro de asignación:
--      muestra TODOS los futuros, con su chofer/unidad actual. Vacío =
--      esta semana; con texto = búsqueda en cualquier fecha futura.
--   2) cancel_service(p_service_id) -- marca el servicio como CANCELADO.
--   3) update_service(p_service_id, p_field, p_value) -- cambia un campo.
--
-- Requiere haber corrido antes:
--   sql/migrations/20260725_fase15_buscar_servicios_asignar.sql
-- =====================================================

-- 0) Estado CANCELLED para servicios
INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES ('CANCELLED', 'Cancelado', 9)) v(code, label, sort_order)
WHERE g.code = 'SERVICE_STATUS'
AND NOT EXISTS (SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code);


--------------------------------------------------------
-- 1) find_future_services(p_query) -- buscador general (modificar/cancelar)
--    Mismo estilo que find_services_to_assign (Fase 15) pero SIN filtro de
--    modo/pendiente: lista todos los servicios futuros no cancelados.
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.find_future_services(p_query text)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
WITH enriched AS (
  SELECT
    s.id, s.scheduled_departure,
    (s.scheduled_departure AT TIME ZONE 'America/Mexico_City')::date AS local_date,
    s.origin, s.destination, s.flight_number, s.passenger_count, s.luggage_count,
    s.client_instructions,
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
    COALESCE(sp.passenger_name, pp.given_names || COALESCE(' ' || pp.last_name, ''),
             org.commercial_name, org.legal_name, '(sin nombre)') AS client_name,
    dp.given_names || COALESCE(' ' || dp.last_name, '') AS driver_name,
    v.internal_code AS vehicle_code,
    st.code AS status_code
  FROM services s
  JOIN service_orders so ON so.id = s.service_order_id
  JOIN accounts acc ON acc.id = so.account_id
  LEFT JOIN people pp ON pp.id = acc.person_id
  LEFT JOIN organizations org ON org.id = acc.organization_id
  LEFT JOIN service_passengers sp ON sp.service_id = s.id AND sp.is_primary_contact = true
  LEFT JOIN catalog_items st ON st.id = s.status_id
  LEFT JOIN LATERAL (
      SELECT a.driver_id, a.vehicle_id FROM assignments a WHERE a.service_id = s.id
      ORDER BY a.created_at DESC LIMIT 1
  ) asg ON true
  LEFT JOIN drivers drv ON drv.id = asg.driver_id
  LEFT JOIN people dp ON dp.id = drv.person_id
  LEFT JOIN vehicles v ON v.id = asg.vehicle_id
  WHERE s.scheduled_departure IS NOT NULL
),
picked AS (
  SELECT e.* FROM enriched e
  WHERE e.local_date >= (now() AT TIME ZONE 'America/Mexico_City')::date
    AND COALESCE(e.status_code, '') <> 'CANCELLED'
    AND (
      ( NULLIF(trim(coalesce(p_query, '')), '') IS NULL
        AND e.local_date <= (now() AT TIME ZONE 'America/Mexico_City')::date + 7 )
      OR
      ( NULLIF(trim(coalesce(p_query, '')), '') IS NOT NULL
        AND translate(lower(concat_ws(' ', e.client_name, e.origin, e.destination,
                                      e.flight_number, e.fecha_txt, e.weekday, e.mes_txt)),
                      'áéíóúñ', 'aeioun')
            LIKE '%' || translate(lower(trim(p_query)), 'áéíóúñ', 'aeioun') || '%' )
    )
  ORDER BY e.scheduled_departure
  LIMIT 25
)
SELECT jsonb_build_object('services', COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id, 'fecha_txt', p.fecha_txt, 'hora_txt', p.hora_txt, 'weekday', p.weekday,
      'origin', p.origin, 'destination', p.destination, 'client_name', p.client_name,
      'flight_number', p.flight_number, 'driver_name', p.driver_name, 'vehicle_code', p.vehicle_code,
      'passenger_count', p.passenger_count, 'luggage_count', p.luggage_count,
      'client_instructions', p.client_instructions
    ) ORDER BY p.scheduled_departure), '[]'::jsonb))
FROM picked p;
$function$;

CREATE OR REPLACE FUNCTION public.find_future_services(p_query text)
RETURNS jsonb LANGUAGE sql AS $function$ SELECT atlas.find_future_services(p_query); $function$;


--------------------------------------------------------
-- 2) cancel_service(p_service_id) -- marca el servicio como cancelado
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.cancel_service(p_service_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE v_cancelled INTEGER;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM services WHERE id = p_service_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'no existe ese servicio');
  END IF;
  v_cancelled := atlas.catalog('SERVICE_STATUS', 'CANCELLED');
  UPDATE services SET status_id = v_cancelled, updated_at = now() WHERE id = p_service_id;
  RETURN jsonb_build_object('success', true, 'service_id', p_service_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_service(p_service_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $function$ SELECT atlas.cancel_service(p_service_id); $function$;


--------------------------------------------------------
-- 3) update_service(p_service_id, p_field, p_value) -- cambia un campo
--    Campos permitidos (whitelist -- nunca se arma SQL con texto libre del
--    usuario, cada campo es una rama fija):
--      horario  -> scheduled_departure (formato 'DD/MM/AAAA HH:MM', zona SMA)
--      origen   -> origin
--      destino  -> destination
--      pasajeros-> passenger_count (entero >= 0)
--      maletas  -> luggage_count (entero >= 0)
--      vuelo    -> flight_number
--      nota     -> client_instructions
--    Devuelve success + una etiqueta legible del nuevo valor para confirmar.
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.update_service(p_service_id uuid, p_field text, p_value text)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_ts timestamptz;
  v_int integer;
  v_shown text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM services WHERE id = p_service_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'no existe ese servicio');
  END IF;

  IF p_field = 'horario' THEN
    BEGIN
      -- Interpretar el texto como hora LOCAL de San Miguel: primero se
      -- obtiene el wall-clock naive (::timestamp) y luego se ancla a la
      -- zona con AT TIME ZONE, para no depender de la zona de la sesión.
      v_ts := (to_timestamp(trim(p_value), 'DD/MM/YYYY HH24:MI')::timestamp) AT TIME ZONE 'America/Mexico_City';
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'error', 'formato de fecha/hora inválido. Usa DD/MM/AAAA HH:MM, por ejemplo 15/08/2026 14:30');
    END;
    UPDATE services SET scheduled_departure = v_ts, updated_at = now() WHERE id = p_service_id;
    v_shown := to_char(v_ts AT TIME ZONE 'America/Mexico_City', 'DD/MM/YYYY HH24:MI');

  ELSIF p_field = 'origen' THEN
    UPDATE services SET origin = NULLIF(trim(p_value), ''), updated_at = now() WHERE id = p_service_id;
    v_shown := trim(p_value);

  ELSIF p_field = 'destino' THEN
    UPDATE services SET destination = NULLIF(trim(p_value), ''), updated_at = now() WHERE id = p_service_id;
    v_shown := trim(p_value);

  ELSIF p_field = 'pasajeros' THEN
    v_int := NULLIF(trim(p_value), '')::integer;
    IF v_int IS NULL OR v_int < 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'número de pasajeros inválido');
    END IF;
    UPDATE services SET passenger_count = v_int, updated_at = now() WHERE id = p_service_id;
    v_shown := v_int::text;

  ELSIF p_field = 'maletas' THEN
    v_int := NULLIF(trim(p_value), '')::integer;
    IF v_int IS NULL OR v_int < 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'número de maletas inválido');
    END IF;
    UPDATE services SET luggage_count = v_int, updated_at = now() WHERE id = p_service_id;
    v_shown := v_int::text;

  ELSIF p_field = 'vuelo' THEN
    UPDATE services SET flight_number = NULLIF(trim(p_value), ''), updated_at = now() WHERE id = p_service_id;
    v_shown := trim(p_value);

  ELSIF p_field = 'nota' THEN
    UPDATE services SET client_instructions = NULLIF(trim(p_value), ''), updated_at = now() WHERE id = p_service_id;
    v_shown := trim(p_value);

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'campo no reconocido: ' || COALESCE(p_field, '(vacío)'));
  END IF;

  RETURN jsonb_build_object('success', true, 'service_id', p_service_id, 'field', p_field, 'new_value', v_shown);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'no se pudo actualizar el valor');
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_service(p_service_id uuid, p_field text, p_value text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $function$ SELECT atlas.update_service(p_service_id, p_field, p_value); $function$;
