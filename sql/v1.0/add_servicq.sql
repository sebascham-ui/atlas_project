

DECLARE

    v_service_id UUID;
    v_direction TEXT;

BEGIN

    ------------------------------------------------------
    -- Normalizar dirección
    ------------------------------------------------------

    IF p_service->>'direction' = 'ARRIVAL' THEN
        v_direction := 'OUTBOUND';

    ELSIF p_service->>'direction' = 'DEPARTURE' THEN
        v_direction := 'RETURN';

    ELSE
        v_direction := COALESCE(
            p_service->>'direction',
            'OUTBOUND'
        );
    END IF;

    ------------------------------------------------------
    -- Crear servicio
    ------------------------------------------------------

    INSERT INTO services(

        service_order_id,

        service_type_id,

        direction_id,

        origin,

        destination,

        scheduled_departure,

        scheduled_arrival,

        passenger_count,

        luggage_count,

        flight_number,

        flight_datetime,

        pickup_location,

        dropoff_location,

        client_instructions,

        status_id,

        service_context

    )

    VALUES(

        p_service_order_id,

        atlas.catalog(
            'SERVICE_TYPE',
            COALESCE(
                p_service->>'service_type',
                p_service->>'type',
                'TRANSFER'
            )
        ),

        atlas.catalog(
            'SERVICE_DIRECTION',
            v_direction
        ),

        COALESCE(
            p_service->>'origin',
            p_service->>'pickup_location'
        ),

        COALESCE(
            p_service->>'destination',
            p_service->>'dropoff_location'
        ),

        NULLIF(
            COALESCE(
                p_service->>'scheduled_departure',
                p_service->>'pickup_datetime'
            ),
            ''
        )::timestamptz,

        NULLIF(
            COALESCE(
                p_service->>'scheduled_arrival',
                p_service->>'dropoff_datetime'
            ),
            ''
        )::timestamptz,

        COALESCE(
            NULLIF(p_service->>'passenger_count','')::integer,
            NULLIF(p_service->>'passengers','')::integer,
            1
        ),

        COALESCE(
            NULLIF(p_service->>'luggage_count','')::integer,
            0
        ),

        COALESCE(
            p_service->>'flight_number',
            p_service->>'flight_code'
        ),

        NULLIF(
            COALESCE(
                p_service->>'flight_datetime',
                p_service->>'pickup_datetime'
            ),
            ''
        )::timestamptz,

        p_service->>'pickup_location',

        p_service->>'dropoff_location',

        COALESCE(
            p_service->>'client_instructions',
            p_service->>'notes'
        ),

        atlas.catalog(
            'SERVICE_STATUS',
            'RECEIVED'
        ),

        jsonb_build_object(

            'version', 1,

            'created_by', 'RESERVATION_ENGINE',

            'created_at', NOW(),

            'knowledge', p_service

        )

    )

    RETURNING id
    INTO v_service_id;

    RETURN v_service_id;

END;

