

DECLARE

    v_order_id UUID;
    v_next_sequence INTEGER;
    v_folio TEXT;

BEGIN

    ------------------------------------------------------
    -- Calcular consecutivo del día
    ------------------------------------------------------

    SELECT COUNT(*) + 1
    INTO v_next_sequence
    FROM service_orders
    WHERE reservation_date::date = CURRENT_DATE;

    ------------------------------------------------------
    -- Generar folio
    ------------------------------------------------------

    v_folio :=
        'AT-' ||
        to_char(CURRENT_DATE,'YYYYMMDD') ||
        '-' ||
        lpad(v_next_sequence::text,6,'0');

    ------------------------------------------------------
    -- Crear orden
    ------------------------------------------------------

    INSERT INTO service_orders(

        folio,
        account_id,
        reservation_date,
        priority_id,
        status_id,
        internal_notes,
        atlas_context

    )

    VALUES(

        v_folio,

        p_account_id,

        NOW(),

        atlas.catalog(
            'SERVICE_PRIORITY',
            p_priority_code
        ),

        atlas.catalog(
            'SERVICE_ORDER_STATUS',
            'RECEIVED'
        ),

        p_internal_notes,

        COALESCE(
            p_atlas_context,
            '{}'::jsonb
        )

    )

    RETURNING id
    INTO v_order_id;

    RETURN v_order_id;

END;

