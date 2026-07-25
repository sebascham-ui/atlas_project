-- =====================================================
-- FASE 9 -- Cruzar datos reales de unidades en el bot de Telegram
-- Atlas Project -- 2026-07-24
--
-- Para qué sirve: hoy el bot de Telegram (ATLAS - Bot de Telegram
-- (Actualizaciones Internas)) le pregunta al chofer "¿Qué unidad?" como
-- texto libre (placa o número económico, escrito a mano) cuando reporta
-- una falla -- nunca se conecta con la tabla "vehicles" real que ya
-- existe (20 unidades, con código interno U-01...U-20, marca, modelo,
-- placas). Esto significa que incidents.vehicle_id y expenses.vehicle_id
-- (ambas columnas YA EXISTEN en el esquema) se quedan siempre vacías.
--
-- Esta migración prepara el lado de base de datos para que el bot pueda:
--   1) Mostrarle al chofer una lista real de unidades activas (en vez de
--      que escriba el nombre a mano, con riesgo de errores de dedo).
--   2) Guardar el vehicle_id correcto en incidents/expenses cuando se
--      reporta una falla o un gasto.
--   3) Registrar lecturas de kilometraje por unidad a lo largo del
--      tiempo (tabla nueva vehicle_odometer_readings) -- esto es la base
--      real para más adelante comparar contra route_travel_times.expected_km
--      y detectar gastos o desgaste fuera de lo normal, en vez de
--      construir un catálogo de rutas alternas (ver conversación del
--      proyecto, 2026-07-24 -- se descartó esa idea a favor de medir
--      datos reales).
--
-- Requiere haber corrido antes:
--   sql/migrations/20260724_fase4_catalogo_vehiculos.sql (tabla vehicles)
--   sql/v1.0/log_incident_v1.sql
--   sql/v1.0/log_expense_v1.sql
-- =====================================================


--------------------------------------------------------
-- 1) atlas.list_active_vehicles() -- para que el bot arme la lista que
--    le muestra al chofer, siempre con datos reales y actualizados.
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.list_active_vehicles()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  -- Se regresa envuelto en un objeto ({"vehicles": [...]}), no como
  -- arreglo suelto -- así el nodo HTTP de n8n lo trae como UN solo item
  -- (.json.vehicles), en vez de que n8n reparta el arreglo en varios
  -- items automáticamente (que rompería $('Listar Unidades
  -- Activas').first().json en el flujo del bot).
  SELECT jsonb_build_object('vehicles', COALESCE(jsonb_agg(
      jsonb_build_object(
        'code', v.internal_code,
        'label', v.internal_code || ' · ' || COALESCE(v.brand,'') ||
                 CASE WHEN v.model IS NOT NULL THEN ' ' || v.model ELSE '' END ||
                 CASE WHEN v.license_plate IS NOT NULL THEN ' (' || v.license_plate || ')' ELSE '' END
      )
      ORDER BY v.internal_code
  ), '[]'::jsonb))
  FROM vehicles v
  JOIN catalog_items st ON st.id = v.status_id
  WHERE st.code = 'ACTIVE';
$function$;

CREATE OR REPLACE FUNCTION public.list_active_vehicles()
RETURNS jsonb
LANGUAGE sql
AS $function$
  SELECT atlas.list_active_vehicles();
$function$;


--------------------------------------------------------
-- 2) Resolver un código de unidad (ej. "U-05", o "U-05 · Toyota ...",
--    el bot puede mandar la fila completa que el chofer eligió) al
--    vehicle_id real. Devuelve NULL si no hay match -- nunca truena,
--    para no romper el registro del incidente/gasto solo porque la
--    unidad no se pudo identificar.
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.resolve_vehicle_id(p_vehicle_code TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
AS $function$
  -- Acepta tanto el código solo ("U-05") como la etiqueta completa que
  -- arma list_active_vehicles ("U-05 · Toyota Corolla (ABC-123)") --
  -- internal_code nunca tiene espacios, así que basta con la primera
  -- palabra.
  SELECT id FROM vehicles
  WHERE p_vehicle_code IS NOT NULL
    AND upper(internal_code) = upper(trim(split_part(trim(p_vehicle_code), ' ', 1)))
  LIMIT 1;
$function$;


--------------------------------------------------------
-- 3) Kilometraje -- historial de lecturas por unidad, + el kilometraje
--    "actual" en vehicles.current_km (esa columna ya existía, no se usaba).
--    Se define antes de log_expense porque log_expense la llama.
--------------------------------------------------------

CREATE TABLE IF NOT EXISTS vehicle_odometer_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    reading_km INTEGER NOT NULL,
    recorded_by UUID REFERENCES people(id),
    -- de dónde vino el dato: 'manual' (opción dedicada del bot),
    -- 'gasto_gasolina' (se capturó junto con la carga de gasolina), etc.
    source TEXT NOT NULL DEFAULT 'manual',
    -- true si esta lectura es MENOR al current_km previo del vehículo --
    -- normalmente un odómetro no retrocede, así que esto casi siempre
    -- significa un error de captura. No se bloquea el registro (mejor
    -- guardarlo y avisar, que perder el dato) -- el bot puede usar esta
    -- bandera para avisarle al chofer o al staff.
    is_below_previous BOOLEAN NOT NULL DEFAULT false,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_odometer_readings_vehicle
    ON vehicle_odometer_readings(vehicle_id, recorded_at DESC);

CREATE OR REPLACE FUNCTION atlas.log_odometer_reading(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_vehicle_id UUID;
    v_reading INTEGER;
    v_previous_km INTEGER;
    v_below BOOLEAN;
    v_reading_id UUID;
BEGIN
    v_vehicle_id := atlas.resolve_vehicle_id(p_payload->>'vehicle_code');
    IF v_vehicle_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'no reconocí esa unidad: ' || COALESCE(p_payload->>'vehicle_code', '(vacío)'));
    END IF;

    v_reading := NULLIF(p_payload->>'reading_km', '')::integer;
    IF v_reading IS NULL OR v_reading < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'kilometraje inválido');
    END IF;

    SELECT current_km INTO v_previous_km FROM vehicles WHERE id = v_vehicle_id;
    v_below := (v_previous_km IS NOT NULL AND v_reading < v_previous_km);

    INSERT INTO vehicle_odometer_readings(vehicle_id, reading_km, recorded_by, source, is_below_previous)
    VALUES(
        v_vehicle_id,
        v_reading,
        NULLIF(p_payload->>'recorded_by', '')::uuid,
        COALESCE(NULLIF(p_payload->>'source', ''), 'manual'),
        v_below
    )
    RETURNING id INTO v_reading_id;

    -- Solo se actualiza vehicles.current_km si la lectura no va "para
    -- atrás" -- así el "kilometraje actual" del vehículo nunca retrocede
    -- por un error de captura, aunque el historial sí guarda la lectura
    -- rara para que el staff la revise.
    IF NOT v_below THEN
        UPDATE vehicles SET current_km = v_reading, updated_at = now() WHERE id = v_vehicle_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'reading_id', v_reading_id,
        'is_below_previous', v_below
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.log_odometer_reading(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.log_odometer_reading(p_payload);
$function$;


--------------------------------------------------------
-- 4) log_incident -- ahora acepta vehicle_code (opcional, retrocompatible
--    -- si no viene o no hace match, vehicle_id se queda NULL, igual que
--    hoy).
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.log_incident(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_type_id INTEGER;
    v_severity_id INTEGER;
    v_status_id INTEGER;
    v_incident_id UUID;
    v_description TEXT;
    v_vehicle_id UUID;
BEGIN
    v_description := trim(p_payload->>'description');

    IF v_description IS NULL OR v_description = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'se requiere description');
    END IF;

    v_type_id := atlas.catalog('INCIDENT_TYPE', p_payload->>'incident_type_code');
    IF v_type_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'tipo de incidente inválido: ' || COALESCE(p_payload->>'incident_type_code', '(vacío)')
        );
    END IF;

    v_severity_id := atlas.catalog('INCIDENT_SEVERITY', p_payload->>'severity_code');
    IF v_severity_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'severidad inválida: ' || COALESCE(p_payload->>'severity_code', '(vacío)')
        );
    END IF;

    v_status_id := atlas.catalog('INCIDENT_STATUS', 'REPORTADO');
    v_vehicle_id := atlas.resolve_vehicle_id(p_payload->>'vehicle_code');

    INSERT INTO incidents(
        driver_id,
        vehicle_id,
        incident_type_id,
        severity_id,
        status_id,
        description,
        incident_location_text,
        reported_by
    )
    VALUES(
        NULLIF(p_payload->>'driver_id', '')::uuid,
        v_vehicle_id,
        v_type_id,
        v_severity_id,
        v_status_id,
        v_description,
        NULLIF(p_payload->>'location_text', ''),
        NULLIF(p_payload->>'reported_by', '')::uuid
    )
    RETURNING id INTO v_incident_id;

    RETURN jsonb_build_object(
        'success', true,
        'incident_id', v_incident_id,
        'vehicle_matched', v_vehicle_id IS NOT NULL
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.log_incident(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.log_incident(p_payload);
$function$;


--------------------------------------------------------
-- 5) log_expense -- mismo tratamiento de vehicle_code, MÁS: si viene
--    odometer_km, registra la lectura (usando log_odometer_reading,
--    punto 3) sin bloquear el registro del gasto si algo del
--    kilometraje falla.
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.log_expense(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_category_id UUID;
    v_expense_id UUID;
    v_amount NUMERIC;
    v_category_name TEXT;
    v_vehicle_id UUID;
    v_odometer_result jsonb;
BEGIN
    v_category_name := trim(p_payload->>'category_name');
    v_amount := NULLIF(p_payload->>'amount', '')::numeric;

    IF v_category_name IS NULL OR v_category_name = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'se requiere category_name');
    END IF;

    IF v_amount IS NULL OR v_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'el monto debe ser mayor a cero');
    END IF;

    SELECT id INTO v_category_id
    FROM expense_categories
    WHERE name = v_category_name
    LIMIT 1;

    IF v_category_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'no existe la categoría de gasto "' || v_category_name || '"'
        );
    END IF;

    v_vehicle_id := atlas.resolve_vehicle_id(p_payload->>'vehicle_code');

    INSERT INTO expenses(
        expense_category_id,
        driver_id,
        vehicle_id,
        amount,
        currency_id,
        expense_datetime,
        description,
        status_id,
        created_by
    )
    VALUES(
        v_category_id,
        NULLIF(p_payload->>'driver_id', '')::uuid,
        v_vehicle_id,
        v_amount,
        atlas.catalog('CURRENCY', COALESCE(p_payload->>'currency_code', 'MXN')),
        now(),
        p_payload->>'description',
        atlas.catalog('EXPENSE_STATUS', 'REGISTRADO'),
        NULLIF(p_payload->>'created_by', '')::uuid
    )
    RETURNING id INTO v_expense_id;

    -- Kilometraje opcional (ej. lo que el chofer ya escribe al cargar
    -- gasolina) -- si viene y hay unidad identificada, se guarda como una
    -- lectura más. Si falla por lo que sea, NO se cancela el gasto ya
    -- registrado -- el gasto es lo importante, el kilometraje es un plus.
    IF v_vehicle_id IS NOT NULL AND (p_payload->>'odometer_km') IS NOT NULL THEN
        BEGIN
            v_odometer_result := atlas.log_odometer_reading(jsonb_build_object(
                'vehicle_code', p_payload->>'vehicle_code',
                'reading_km', p_payload->>'odometer_km',
                'recorded_by', p_payload->>'created_by',
                'source', 'gasto_gasolina'
            ));
        EXCEPTION WHEN OTHERS THEN
            v_odometer_result := jsonb_build_object('success', false, 'error', 'no se pudo registrar el kilometraje');
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'expense_id', v_expense_id,
        'vehicle_matched', v_vehicle_id IS NOT NULL,
        'odometer', v_odometer_result
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.log_expense(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.log_expense(p_payload);
$function$;
