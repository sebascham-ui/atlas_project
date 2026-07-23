-- =====================================================
-- NUEVO: funciones de actualización y búsqueda de persona
-- Atlas Project -- 2026-07-23
--
-- Para qué sirven: hasta ahora atlas.person() solo sabe BUSCAR-O-CREAR
-- (si no encuentra a alguien por email/teléfono, crea uno nuevo). No
-- existía ninguna función para ACTUALIZAR a una persona que ya existe
-- -- necesaria para el bot de Telegram que administración/choferes
-- van a usar para corregir teléfonos, direcciones y demás.
--
-- Se agregan tres funciones nuevas, todas de solo lectura/escritura
-- sobre `people`, sin tocar nada de lo que ya funciona:
--
--   1. atlas.find_person_by_phone(p_phone) -- búsqueda exacta por
--      teléfono, para cuando el chofer/administración ya trae el
--      número actual del cliente.
--   2. atlas.search_people_by_name(p_query) -- búsqueda flexible por
--      nombre (para cuando no se tiene el teléfono a la mano),
--      devuelve varios candidatos para mostrar como botones en el
--      bot y que el chofer elija el correcto.
--   3. atlas.update_person_contact(p_person_id, p_updates) --
--      actualiza SOLO los campos que vengan en p_updates (los demás
--      quedan igual que estaban), y AVISA con un error claro si el
--      id no existe, en vez de fallar en silencio.
--
-- IMPORTANTE -- lo que NO incluye este script: actualizar dirección.
-- No tengo visibilidad confirmada de si `people` ya tiene una columna
-- de dirección, o si eso vive en la tabla `contacts` (que existe en
-- el proyecto pero que ninguna función usa todavía) o en otro lado.
-- Prefiero no inventar un nombre de columna a ciegas y que la
-- función truene cuando la corras -- cuando tengas tu compu, dime
-- cómo está guardada la dirección hoy (o si no existe todavía) y
-- agrego esa parte en un script aparte.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.find_person_by_phone(p_phone TEXT)
 RETURNS UUID
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_person_id UUID;
BEGIN
    SELECT id
    INTO v_person_id
    FROM people
    WHERE phone = trim(p_phone)
    LIMIT 1;

    RETURN v_person_id;
END;
$function$;


CREATE OR REPLACE FUNCTION public.find_person_by_phone(p_phone TEXT)
 RETURNS UUID
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.find_person_by_phone(p_phone);
$function$;


------------------------------------------------------


CREATE OR REPLACE FUNCTION atlas.search_people_by_name(p_query TEXT)
 RETURNS TABLE(
    id UUID,
    given_names TEXT,
    last_name TEXT,
    phone TEXT,
    email TEXT
 )
 LANGUAGE sql
AS $function$
SELECT
    p.id,
    p.given_names,
    p.last_name,
    p.phone,
    p.email
FROM people p
WHERE (p.given_names || ' ' || COALESCE(p.last_name, '')) ILIKE '%' || trim(p_query) || '%'
ORDER BY p.given_names
LIMIT 10;
$function$;


CREATE OR REPLACE FUNCTION public.search_people_by_name(p_query TEXT)
 RETURNS TABLE(
    id UUID,
    given_names TEXT,
    last_name TEXT,
    phone TEXT,
    email TEXT
 )
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT * FROM atlas.search_people_by_name(p_query);
$function$;


------------------------------------------------------


CREATE OR REPLACE FUNCTION atlas.update_person_contact(
    p_person_id UUID,
    p_updates JSONB
) RETURNS UUID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_given_names TEXT;
    v_last_name TEXT;
    v_phone TEXT;
    v_email TEXT;
    v_language TEXT;
    v_rows_updated INTEGER;
BEGIN
    IF p_person_id IS NULL THEN
        RAISE EXCEPTION 'update_person_contact: se requiere p_person_id';
    END IF;

    -- Solo se leen del JSON los campos que de verdad vengan --
    -- los que no vengan (o vengan vacíos) NO se tocan, se quedan
    -- como estaban.
    v_given_names := NULLIF(trim(p_updates->>'given_names'), '');
    v_last_name := NULLIF(trim(p_updates->>'last_name'), '');
    v_phone := NULLIF(trim(p_updates->>'phone'), '');
    v_email := NULLIF(trim(p_updates->>'email'), '');
    v_language := NULLIF(trim(p_updates->>'preferred_language'), '');

    BEGIN
        UPDATE people
        SET
            given_names = COALESCE(v_given_names, given_names),
            last_name = COALESCE(v_last_name, last_name),
            phone = COALESCE(v_phone, phone),
            email = COALESCE(v_email, email),
            preferred_language_id = CASE
                WHEN v_language IS NOT NULL
                THEN atlas.catalog('LANGUAGE', v_language)
                ELSE preferred_language_id
            END
        WHERE id = p_person_id;
    EXCEPTION WHEN unique_violation THEN
        -- El teléfono o correo nuevo ya le pertenece a OTRA persona
        -- -- en vez de un error críptico de Postgres, uno claro que
        -- el bot le pueda mostrar al chofer/administración.
        RAISE EXCEPTION 'update_person_contact: ese teléfono o correo ya está registrado con otra persona';
    END;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'update_person_contact: no existe ninguna persona con id %', p_person_id;
    END IF;

    RETURN p_person_id;
END;
$function$;


CREATE OR REPLACE FUNCTION public.update_person_contact(p_person_id UUID, p_updates JSONB)
 RETURNS UUID
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.update_person_contact(p_person_id, p_updates);
$function$;
