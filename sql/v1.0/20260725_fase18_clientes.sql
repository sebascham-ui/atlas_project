-- =====================================================
-- FASE 18 -- Gestión de clientes desde el bot de Admin
-- Atlas Project -- 2026-07-25
--
-- Casi toda la lógica ya existe (search_people_by_name, person, account,
-- update_person_contact, log_client_observation). Esta fase solo agrega
-- "envolturas" que devuelven jsonb con success/error (para que el bot no
-- truene con excepciones de Postgres) y dos consultas nuevas de servicios
-- del cliente.
--
--   1) search_clients(p_query)                  -- buscar por nombre
--   2) get_client_card(p_person_id)             -- ficha (datos + account_id)
--   3) create_client(p_client)                  -- crear persona + cuenta
--   4) update_client_contact(id, campo, valor)  -- teléfono/correo/nombre
--   5) client_services(id, scope)               -- futuros / historial
--   6) log_client_preference(id, texto)         -- preferencia/nota
--
-- Requiere: person_update_and_search_v1.sql, person_phone_dedup_v1.sql,
--           account.sql, client_observations_v1.sql.
-- =====================================================

--------------------------------------------------------
-- 1) search_clients(p_query) -- envuelve search_people_by_name en {people:[...]}
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.search_clients(p_query text)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  SELECT jsonb_build_object('people', COALESCE(jsonb_agg(jsonb_build_object(
      'id', s.id,
      'name', trim(s.given_names || ' ' || COALESCE(s.last_name, '')),
      'phone', s.phone,
      'email', s.email
    ) ORDER BY s.given_names), '[]'::jsonb))
  FROM atlas.search_people_by_name(p_query) s;
$function$;

CREATE OR REPLACE FUNCTION public.search_clients(p_query text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $function$ SELECT atlas.search_clients(p_query); $function$;


--------------------------------------------------------
-- 2) get_client_card(p_person_id) -- ficha con datos + su account_id
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.get_client_card(p_person_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  SELECT jsonb_build_object(
    'id', p.id,
    'name', trim(p.given_names || ' ' || COALESCE(p.last_name, '')),
    'phone', p.phone,
    'email', p.email,
    'account_id', (SELECT a.id FROM accounts a WHERE a.person_id = p.id ORDER BY a.created_at LIMIT 1)
  )
  FROM people p WHERE p.id = p_person_id;
$function$;

CREATE OR REPLACE FUNCTION public.get_client_card(p_person_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $function$ SELECT atlas.get_client_card(p_person_id); $function$;


--------------------------------------------------------
-- 3) create_client(p_client) -- crea persona (o la encuentra) + cuenta INDIVIDUAL
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.create_client(p_client jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_person_id uuid;
  v_name text;
BEGIN
  v_person_id := atlas.person(p_client);
  -- Cuenta INDIVIDUAL (mejor esfuerzo: si falla, el cliente igual queda creado)
  BEGIN
    PERFORM atlas.account(p_person_id => v_person_id, p_account_type_code => 'INDIVIDUAL');
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  SELECT trim(given_names || ' ' || COALESCE(last_name, '')) INTO v_name FROM people WHERE id = v_person_id;
  RETURN jsonb_build_object('success', true, 'person_id', v_person_id, 'name', v_name);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_client(p_client jsonb)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $function$ SELECT atlas.create_client(p_client); $function$;


--------------------------------------------------------
-- 4) update_client_contact(p_person_id, p_field, p_value)
--    p_field: 'telefono' | 'correo' | 'nombre'
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.update_client_contact(p_person_id uuid, p_field text, p_value text)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_updates jsonb;
  v_val text := trim(p_value);
  v_parts text[];
  v_given text;
  v_last text;
BEGIN
  IF p_field = 'telefono' THEN
    v_updates := jsonb_build_object('phone', v_val);
  ELSIF p_field = 'correo' THEN
    v_updates := jsonb_build_object('email', v_val);
  ELSIF p_field = 'nombre' THEN
    v_parts := regexp_split_to_array(v_val, '\s+');
    IF array_length(v_parts, 1) = 1 THEN
      v_given := v_parts[1]; v_last := NULL;
    ELSE
      v_last := v_parts[array_length(v_parts,1)];
      v_given := array_to_string(v_parts[1:array_length(v_parts,1)-1], ' ');
    END IF;
    v_updates := jsonb_build_object('given_names', v_given, 'last_name', COALESCE(v_last, ''));
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'campo no reconocido');
  END IF;

  PERFORM atlas.update_person_contact(p_person_id, v_updates);
  RETURN jsonb_build_object('success', true, 'field', p_field, 'new_value', v_val);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_client_contact(p_person_id uuid, p_field text, p_value text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $function$ SELECT atlas.update_client_contact(p_person_id, p_field, p_value); $function$;


--------------------------------------------------------
-- 5) client_services(p_person_id, p_scope) -- 'future' | 'past'
--    Servicios ligados al cliente por su cuenta O como pasajero principal.
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.client_services(p_person_id uuid, p_scope text)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
WITH params AS (SELECT (now() AT TIME ZONE 'America/Mexico_City')::date AS today),
matched AS (
  SELECT DISTINCT s.id, s.scheduled_departure
  FROM services s
  JOIN service_orders so ON so.id = s.service_order_id
  LEFT JOIN accounts acc ON acc.id = so.account_id
  LEFT JOIN service_passengers sp ON sp.service_id = s.id
  LEFT JOIN catalog_items st ON st.id = s.status_id
  WHERE s.scheduled_departure IS NOT NULL
    AND COALESCE(st.code,'') <> 'CANCELLED'
    AND (acc.person_id = p_person_id OR sp.person_id = p_person_id)
),
rows AS (
  SELECT
    s.id, s.scheduled_departure,
    to_char(s.scheduled_departure AT TIME ZONE 'America/Mexico_City', 'DD/MM/YYYY') AS fecha_txt,
    to_char(s.scheduled_departure AT TIME ZONE 'America/Mexico_City', 'HH24:MI') AS hora_txt,
    s.origin, s.destination, s.flight_number,
    dp.given_names || COALESCE(' ' || dp.last_name, '') AS driver_name,
    v.internal_code AS vehicle_code
  FROM matched m
  JOIN services s ON s.id = m.id
  LEFT JOIN LATERAL (
      SELECT a.driver_id, a.vehicle_id FROM assignments a WHERE a.service_id = s.id
      ORDER BY a.created_at DESC LIMIT 1) asg ON true
  LEFT JOIN drivers drv ON drv.id = asg.driver_id
  LEFT JOIN people dp ON dp.id = drv.person_id
  LEFT JOIN vehicles v ON v.id = asg.vehicle_id, params
  WHERE (p_scope = 'future' AND (s.scheduled_departure AT TIME ZONE 'America/Mexico_City')::date >= today)
     OR (p_scope = 'past'   AND (s.scheduled_departure AT TIME ZONE 'America/Mexico_City')::date <  today)
)
SELECT jsonb_build_object(
  'scope', p_scope,
  'services', COALESCE((SELECT jsonb_agg(jsonb_build_object(
      'fecha_txt', r.fecha_txt, 'hora_txt', r.hora_txt,
      'origin', r.origin, 'destination', r.destination, 'flight_number', r.flight_number,
      'driver_name', r.driver_name, 'vehicle_code', r.vehicle_code)
      ORDER BY r.scheduled_departure DESC) FROM rows r), '[]'::jsonb));
$function$;

CREATE OR REPLACE FUNCTION public.client_services(p_person_id uuid, p_scope text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $function$ SELECT atlas.client_services(p_person_id, p_scope); $function$;


--------------------------------------------------------
-- 6) log_client_preference(p_person_id, p_text) -- guarda una preferencia/nota
--------------------------------------------------------
CREATE OR REPLACE FUNCTION atlas.log_client_preference(p_person_id uuid, p_text text)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_account_id uuid;
BEGIN
  IF NULLIF(trim(coalesce(p_text,'')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'la preferencia no puede estar vacía');
  END IF;
  SELECT id INTO v_account_id FROM accounts WHERE person_id = p_person_id ORDER BY created_at LIMIT 1;
  PERFORM atlas.log_client_observation(v_account_id, p_person_id, 'GENERAL_NOTE', trim(p_text));
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.log_client_preference(p_person_id uuid, p_text text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $function$ SELECT atlas.log_client_preference(p_person_id, p_text); $function$;
