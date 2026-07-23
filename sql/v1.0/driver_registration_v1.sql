-- =====================================================
-- FASE 1 -- Alta de choferes
-- Atlas Project -- 2026-07-23
--
-- Una función para dar de alta a un chofer, reutilizando atlas.person()
-- (ADS-006 -- no se duplica la lógica de buscar-o-crear persona).
-- Es idempotente: si la persona ya existe (por teléfono) y ya tiene
-- fila en drivers, no la duplica.
--
-- Todos los campos de drivers más allá de persona/teléfono son
-- opcionales -- se puede dar de alta a un chofer solo con nombre y
-- teléfono, y llenar licencia/fecha de contratación/tarifa después.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.register_driver(p_driver jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id UUID;
    v_driver_id UUID;
BEGIN
    v_person_id := atlas.person(p_driver);

    SELECT id INTO v_driver_id
    FROM drivers
    WHERE person_id = v_person_id;

    IF v_driver_id IS NOT NULL THEN
        RETURN v_driver_id;
    END IF;

    INSERT INTO drivers(
        person_id,
        employee_code,
        hire_date,
        license_number,
        license_expiration,
        speaks_english,
        is_internal,
        hourly_rate,
        status_id
    )
    VALUES(
        v_person_id,
        NULLIF(trim(p_driver->>'employee_code'), ''),
        NULLIF(p_driver->>'hire_date', '')::date,
        NULLIF(trim(p_driver->>'license_number'), ''),
        NULLIF(p_driver->>'license_expiration', '')::date,
        COALESCE((p_driver->>'speaks_english')::boolean, false),
        COALESCE((p_driver->>'is_internal')::boolean, true),
        NULLIF(p_driver->>'hourly_rate', '')::numeric,
        atlas.catalog('PERSON_STATUS', 'ACTIVE')
    )
    RETURNING id INTO v_driver_id;

    RETURN v_driver_id;
END;
$function$;


CREATE OR REPLACE FUNCTION public.register_driver(p_driver jsonb)
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.register_driver(p_driver);
$function$;
