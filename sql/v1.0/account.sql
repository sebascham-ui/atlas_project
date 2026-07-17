

DECLARE

    v_account_id UUID;

BEGIN

    ------------------------------------------------------
    -- Buscar cuenta existente
    ------------------------------------------------------

    SELECT id
    INTO v_account_id
    FROM accounts
    WHERE person_id = p_person_id
      AND account_type_id = atlas.catalog(
            'ACCOUNT_TYPE',
            p_account_type_code
      )
    LIMIT 1;

    ------------------------------------------------------
    -- Si ya existe
    ------------------------------------------------------

    IF v_account_id IS NOT NULL THEN
        RETURN v_account_id;
    END IF;

    ------------------------------------------------------
    -- Crear cuenta
    ------------------------------------------------------

    INSERT INTO accounts(

        person_id,
        account_type_id,
        preferred_currency_id,
        payment_term_id,
        status_id

    )

    VALUES(

        p_person_id,

        atlas.catalog(
            'ACCOUNT_TYPE',
            p_account_type_code
        ),

        atlas.catalog(
            'CURRENCY',
            'MXN'
        ),

        atlas.catalog(
            'PAYMENT_TERM',
            'IMMEDIATE'
        ),

        atlas.catalog(
            'ACCOUNT_STATUS',
            'ACTIVE'
        )

    )

    RETURNING id
    INTO v_account_id;

    RETURN v_account_id;

END;

