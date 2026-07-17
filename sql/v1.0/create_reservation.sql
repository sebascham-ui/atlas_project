DECLARE

    v_person_id UUID;
    v_account_id UUID;
    v_order_id UUID;
    v_service JSONB;
    v_service_id UUID;
    v_service_ids JSONB := '[]'::jsonb;

BEGIN

    ------------------------------------------------------
    -- PERSONA
    ------------------------------------------------------

    v_person_id := atlas.person(
        p_payload->'client'
    );

    ------------------------------------------------------
    -- CUENTA
    ------------------------------------------------------

    v_account_id := atlas.account(
        v_person_id,
        COALESCE(
            p_payload->'account'->>'type',
            'INDIVIDUAL'
        )
    );

    ------------------------------------------------------
    -- ORDEN
    ------------------------------------------------------

    v_order_id := atlas.create_service_order(
    v_account_id,
    COALESCE(
        p_payload->'reservation'->>'customer_notes',
        p_payload->'reservation'->>'internal_notes',
        ''
    ),
    COALESCE(
        p_payload->'reservation'->>'priority',
        'NORMAL'
    ),
    p_payload
);

    ------------------------------------------------------
    -- SERVICIOS
    ------------------------------------------------------

    FOR v_service IN
        SELECT *
        FROM jsonb_array_elements(
            p_payload->'services'
        )
    LOOP

        v_service_id := atlas.add_service(
            v_order_id,
            v_service
        );

        v_service_ids :=
            v_service_ids ||
            jsonb_build_array(
                v_service_id
            );

    END LOOP;

    ------------------------------------------------------
    -- VINCULAR CONVERSACIÓN
    ------------------------------------------------------

    IF p_payload ? 'conversation'
       AND p_payload->'conversation'->>'thread_id' IS NOT NULL
    THEN

        UPDATE conversation_threads
        SET
            account_id = v_account_id,
            service_order_id = v_order_id,
            updated_at = now()
        WHERE id = (
            p_payload->'conversation'->>'thread_id'
        )::uuid;

    END IF;

    ------------------------------------------------------
    -- RESPUESTA
    ------------------------------------------------------

    RETURN jsonb_build_object(

        'success', true,
        'person_id', v_person_id,
        'account_id', v_account_id,
        'service_order_id', v_order_id,
        'service_ids', v_service_ids

    );

END;
