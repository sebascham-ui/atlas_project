-- =====================================================
-- FASE 0 -- Funciones de identidad de personal para el bot
-- Atlas Project -- 2026-07-23
--
-- Requiere haber corrido primero:
--   sql/migrations/20260723_fase0_staff_roles_telegram.sql
--
-- Tres funciones:
--   1. atlas.find_employee_by_chat_id(p_chat_id) -- lo primero que
--      hace el bot con cualquier mensaje: ¿quién es esta persona y
--      qué rol(es) tiene? Devuelve JSON enriquecido, nunca solo
--      TRUE/FALSE (ADS-007).
--   2. atlas.link_telegram_contact(p_phone, p_chat_id) -- vincula el
--      chat_id verificado (compartido por el botón nativo "compartir
--      contacto" de Telegram) con la persona que ya tiene ese
--      teléfono registrado. Si el teléfono no existe o ya está
--      vinculado a otro chat, regresa un error claro, no truena.
--   3. atlas.add_staff_role(p_person_id, p_role_code) -- da de alta
--      un rol de personal (lavacoches/administrador/contador/
--      asistente) a una persona que ya existe en people. Es
--      idempotente: si la persona ya tiene ese rol activo, no
--      duplica.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.find_employee_by_chat_id(p_chat_id TEXT)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id UUID;
    v_given_names TEXT;
    v_last_name TEXT;
    v_is_driver BOOLEAN := false;
    v_driver_id UUID;
    v_staff_roles jsonb;
BEGIN
    SELECT id, given_names, last_name
    INTO v_person_id, v_given_names, v_last_name
    FROM people
    WHERE telegram_chat_id = trim(p_chat_id)
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RETURN jsonb_build_object(
            'found', false
        );
    END IF;

    SELECT id INTO v_driver_id
    FROM drivers
    WHERE person_id = v_person_id
    LIMIT 1;

    v_is_driver := (v_driver_id IS NOT NULL);

    SELECT COALESCE(jsonb_agg(ci.code), '[]'::jsonb)
    INTO v_staff_roles
    FROM staff_roles sr
    JOIN catalog_items ci ON ci.id = sr.role_type_id
    JOIN catalog_items st ON st.id = sr.status_id
    WHERE sr.person_id = v_person_id
    AND st.code = 'ACTIVE'
    AND (sr.end_date IS NULL OR sr.end_date >= CURRENT_DATE);

    RETURN jsonb_build_object(
        'found', true,
        'person_id', v_person_id,
        'given_names', v_given_names,
        'last_name', v_last_name,
        'is_driver', v_is_driver,
        'driver_id', v_driver_id,
        'staff_roles', v_staff_roles
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.find_employee_by_chat_id(p_chat_id TEXT)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.find_employee_by_chat_id(p_chat_id);
$function$;


------------------------------------------------------


CREATE OR REPLACE FUNCTION atlas.link_telegram_contact(p_phone TEXT, p_chat_id TEXT)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id UUID;
    v_existing_chat_owner UUID;
BEGIN
    IF p_phone IS NULL OR trim(p_phone) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'se requiere un teléfono');
    END IF;

    IF p_chat_id IS NULL OR trim(p_chat_id) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'se requiere un chat_id');
    END IF;

    SELECT id INTO v_person_id
    FROM people
    WHERE phone = trim(p_phone)
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'no existe ninguna persona registrada con ese teléfono'
        );
    END IF;

    SELECT id INTO v_existing_chat_owner
    FROM people
    WHERE telegram_chat_id = trim(p_chat_id)
    AND id <> v_person_id
    LIMIT 1;

    IF v_existing_chat_owner IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ese chat de Telegram ya está vinculado a otra persona'
        );
    END IF;

    UPDATE people
    SET telegram_chat_id = trim(p_chat_id)
    WHERE id = v_person_id;

    RETURN jsonb_build_object(
        'success', true,
        'person_id', v_person_id
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.link_telegram_contact(p_phone TEXT, p_chat_id TEXT)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.link_telegram_contact(p_phone, p_chat_id);
$function$;


------------------------------------------------------


CREATE OR REPLACE FUNCTION atlas.add_staff_role(p_person_id UUID, p_role_code TEXT)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_role_type_id INTEGER;
    v_active_status_id INTEGER;
    v_existing_id UUID;
    v_new_id UUID;
BEGIN
    IF p_person_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'se requiere p_person_id');
    END IF;

    v_role_type_id := atlas.catalog('STAFF_ROLE', p_role_code);
    v_active_status_id := atlas.catalog('PERSON_STATUS', 'ACTIVE');

    SELECT id INTO v_existing_id
    FROM staff_roles
    WHERE person_id = p_person_id
    AND role_type_id = v_role_type_id
    AND status_id = v_active_status_id
    AND (end_date IS NULL OR end_date >= CURRENT_DATE)
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'staff_role_id', v_existing_id,
            'warnings', jsonb_build_array('esta persona ya tenía ese rol activo, no se duplicó')
        );
    END IF;

    INSERT INTO staff_roles(person_id, role_type_id, status_id)
    VALUES(p_person_id, v_role_type_id, v_active_status_id)
    RETURNING id INTO v_new_id;

    RETURN jsonb_build_object(
        'success', true,
        'staff_role_id', v_new_id
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.add_staff_role(p_person_id UUID, p_role_code TEXT)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.add_staff_role(p_person_id, p_role_code);
$function$;
