-- =====================================================
-- FIX: atlas.person() debe deduplicar también por teléfono
-- Atlas Project -- 2026-07-23
--
-- Problema real encontrado procesando el quinto trimestre de la
-- recopilación histórica: un correo traía teléfono pero SIN correo
-- (email vacío). Como atlas.person() solo buscaba una persona
-- existente por email, no encontró coincidencia y trató de INSERTAR
-- una persona nueva -- pero ese mismo teléfono ya existía en otro
-- registro de persona (ej. el mismo cliente había escrito antes desde
-- un correo distinto, o alguien más ya tenía registrado ese número).
-- Eso violó la restricción única "uq_people_phone" y tumbó TODO el
-- lote a mitad de camino, igual que el bug de observation_type de
-- antes.
--
-- Fix, en dos partes:
--   1. Igual que ya se hace con email, ahora también se busca una
--      persona existente por teléfono ANTES de intentar insertar.
--   2. Como respaldo extra (por si dos búsquedas casi simultáneas
--      pasan la validación al mismo tiempo, o por cualquier otra
--      combinación no prevista), si el INSERT de todos modos choca
--      con la restricción única, en vez de tronar se reutiliza el
--      registro existente que causó el choque. Esto protege contra
--      CUALQUIER futuro conflicto de este tipo sin necesidad de
--      adivinar todos los casos de antemano.
--
-- Nota de diseño: esto trata el teléfono como una segunda llave de
-- identidad, igual que ya se trata el email -- es la misma política
-- que ya aceptamos implícitamente (dos personas que comparten un
-- mismo correo ya se fusionan en un solo registro; ahora lo mismo
-- aplica si comparten teléfono). Para una empresa familiar pequeña
-- esto es la simplificación razonable; si en el futuro hace falta
-- distinguir personas que comparten teléfono (ej. una agencia que
-- reserva para varios pasajeros distintos desde el mismo número),
-- eso se resuelve entonces, no ahora.
--
-- Retrocompatible: no cambia nada del comportamiento para el flujo
-- en vivo de reservaciones en el caso normal (sin colisión de datos).
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.person(p_client jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id UUID;
    v_full_name TEXT;
    v_email TEXT;
    v_phone TEXT;
    v_language TEXT;
    v_name_parts TEXT[];
    v_given_names TEXT;
    v_last_name TEXT;
BEGIN
    ------------------------------------------------------
    -- Leer JSON
    ------------------------------------------------------
    v_email := NULLIF(trim(p_client->>'email'),'');
    v_phone := NULLIF(trim(p_client->>'phone'),'');
    v_language := COALESCE(
        p_client->>'preferred_language',
        'ES'
    );
    ------------------------------------------------------
    -- Buscar por email
    ------------------------------------------------------
    IF v_email IS NOT NULL THEN
        SELECT id
        INTO v_person_id
        FROM people
        WHERE LOWER(email)=LOWER(v_email)
        LIMIT 1;
    END IF;
    ------------------------------------------------------
    -- Si no hubo match por email, buscar por teléfono
    ------------------------------------------------------
    IF v_person_id IS NULL AND v_phone IS NOT NULL THEN
        SELECT id
        INTO v_person_id
        FROM people
        WHERE phone = v_phone
        LIMIT 1;
    END IF;
    IF v_person_id IS NOT NULL THEN
        RETURN v_person_id;
    END IF;
    ------------------------------------------------------
    -- Nombre: usar given_names/last_name si vienen directo;
    -- si no, caer al comportamiento anterior (partir full_name)
    ------------------------------------------------------
    v_given_names := NULLIF(trim(p_client->>'given_names'), '');
    v_last_name := NULLIF(trim(p_client->>'last_name'), '');

    IF v_given_names IS NULL AND v_last_name IS NULL THEN
        v_full_name := trim(p_client->>'full_name');
        v_name_parts := regexp_split_to_array(v_full_name,'\s+');
        IF array_length(v_name_parts,1)=1 THEN
            v_given_names := v_name_parts[1];
            v_last_name := NULL;
        ELSE
            v_last_name := v_name_parts[array_length(v_name_parts,1)];
            v_given_names := array_to_string(
                v_name_parts[
                    1:array_length(v_name_parts,1)-1
                ],
                ' '
            );
        END IF;
    END IF;
    ------------------------------------------------------
    -- Crear persona -- con respaldo si de todos modos choca
    -- con una restricción única no detectada arriba
    ------------------------------------------------------
    BEGIN
        INSERT INTO people(
            given_names,
            last_name,
            phone,
            email,
            preferred_language_id,
            status_id
        )
        VALUES(
            v_given_names,
            v_last_name,
            v_phone,
            v_email,
            atlas.catalog(
                'LANGUAGE',
                v_language
            ),
            atlas.catalog(
                'PERSON_STATUS',
                'ACTIVE'
            )
        )
        RETURNING id
        INTO v_person_id;
    EXCEPTION WHEN unique_violation THEN
        SELECT id
        INTO v_person_id
        FROM people
        WHERE (v_email IS NOT NULL AND LOWER(email) = LOWER(v_email))
           OR (v_phone IS NOT NULL AND phone = v_phone)
        LIMIT 1;
    END;

    RETURN v_person_id;
END;
$function$;


CREATE OR REPLACE FUNCTION public.person(p_client jsonb)
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.person(p_client);
$function$;
