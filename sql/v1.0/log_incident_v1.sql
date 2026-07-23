-- =====================================================
-- FASE 2 -- Registrar un incidente (chofer o prueba de administrador)
-- Atlas Project -- 2026-07-23
--
-- Requiere haber corrido antes:
--   sql/migrations/20260723_fase2_incident_catalogs.sql
--
-- p_payload:
--   incident_type_code  (obligatorio -- uno de los codes de INCIDENT_TYPE:
--                         ACCIDENTE, FALLA_MECANICA, RETRASO,
--                         PROBLEMA_PASAJERO, OBJETO_OLVIDADO, MULTA, OTRO)
--   severity_code        (obligatorio -- BAJA, MEDIA, ALTA, CRITICA)
--   description           (obligatorio)
--   location_text          (opcional -- texto libre, no lat/lng)
--   driver_id              (opcional -- null cuando lo registra un
--                           administrador de prueba, no un chofer real)
--   reported_by             (person_id de quien lo reporta -- chofer o admin)
--
-- El estatus inicial siempre es REPORTADO -- el cambio a
-- en_atención/resuelto/cerrado es tarea de administración, todavía
-- no construida (Fase 3).
--
-- Devuelve JSON enriquecido (ADS-007), nunca solo TRUE/FALSE.
-- =====================================================

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

    INSERT INTO incidents(
        driver_id,
        incident_type_id,
        severity_id,
        status_id,
        description,
        incident_location_text,
        reported_by
    )
    VALUES(
        NULLIF(p_payload->>'driver_id', '')::uuid,
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
        'incident_id', v_incident_id
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
