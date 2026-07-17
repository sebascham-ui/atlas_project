

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

    v_full_name := trim(p_client->>'full_name');
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

    IF v_person_id IS NOT NULL THEN
        RETURN v_person_id;
    END IF;

    ------------------------------------------------------
    -- Separar nombre
    ------------------------------------------------------

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

    ------------------------------------------------------
    -- Crear persona
    ------------------------------------------------------

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

    RETURN v_person_id;

END;

