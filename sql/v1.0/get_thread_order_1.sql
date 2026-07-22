-- =====================================================
-- get_thread_order
-- Atlas Project -- 2026-07-22
--
-- Para qué sirve: dado un hilo de conversación (conversation_threads.id),
-- regresa la orden de servicio ligada a ese hilo -- sin importar su
-- estado (Recibida o Confirmada), junto con el detalle completo de
-- cada servicio que ya tiene registrado (hora, ruta, vuelo, pasajeros,
-- equipaje, notas). Si la orden ya está Cancelada, o no hay ninguna
-- orden ligada al hilo, regresa NULL.
--
-- En qué se diferencia de get_thread_open_order: esa función (ya
-- instalada) solo reconoce órdenes en "Recibida", y solo regresa
-- {order_id, folio} -- pensada para decidir si un correo nuevo es
-- continuación de una reservación AÚN NO CONFIRMADA (Fase 1, evitar
-- duplicados). Esta función es para UPDATE_ENGINE: el cliente puede
-- pedir modificar una reservación que el equipo YA CONFIRMÓ, y para
-- redactar un borrador de respuesta certero (IA) hace falta ver los
-- datos actuales de cada servicio -- no solo saber que la orden existe.
--
-- Devuelve, por ejemplo:
-- {
--   "order_id": "...",
--   "folio": "AT-20260722-000004",
--   "status": "CONFIRMED",
--   "services": [
--     {
--       "service_id": "...",
--       "service_type": "TRANSFER",
--       "direction": "OUTBOUND",
--       "origin": "Aeropuerto de Querétaro (QRO)",
--       "destination": "Hotel Casa Blanca, San Miguel de Allende",
--       "scheduled_departure": "2026-08-03T15:00:00-06:00",
--       "flight_number": "AM123",
--       "passenger_count": 2,
--       "luggage_count": 2,
--       "client_instructions": "Viajan con un perro pequeño"
--     }
--   ]
-- }
--
-- Cómo instalarlo: entra al SQL Editor de Supabase y pega este archivo
-- completo, luego ejecútalo. No modifica ninguna tabla existente, solo
-- agrega esta función nueva.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.get_thread_order(p_thread_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_order_id uuid;
    v_folio text;
    v_status_code text;
    v_services jsonb;
BEGIN
    SELECT so.id, so.folio, ci.code
      INTO v_order_id, v_folio, v_status_code
      FROM conversation_threads ct
      JOIN service_orders so ON so.id = ct.service_order_id
      JOIN catalog_items ci ON ci.id = so.status_id
     WHERE ct.id = p_thread_id
     LIMIT 1;

    -- Sin orden ligada al hilo, o la orden ya está Cancelada -- en
    -- ambos casos no hay nada que UPDATE_ENGINE pueda ofrecer modificar.
    IF v_order_id IS NULL OR v_status_code = 'CANCELLED' THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'service_id', s.id,
            'service_type', st.code,
            'direction', sd.code,
            'origin', s.origin,
            'destination', s.destination,
            'scheduled_departure', s.scheduled_departure,
            'scheduled_arrival', s.scheduled_arrival,
            'flight_number', s.flight_number,
            'passenger_count', s.passenger_count,
            'luggage_count', s.luggage_count,
            'client_instructions', s.client_instructions
        )
        ORDER BY s.scheduled_departure NULLS LAST
    ), '[]'::jsonb)
      INTO v_services
      FROM services s
      JOIN catalog_items st ON st.id = s.service_type_id
      JOIN catalog_items sd ON sd.id = s.direction_id
     WHERE s.service_order_id = v_order_id;

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'folio', v_folio,
        'status', v_status_code,
        'services', v_services
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_thread_order(p_thread_id uuid)
 RETURNS jsonb
 LANGUAGE sql
AS $function$
SELECT atlas.get_thread_order(p_thread_id);
$function$;


-- ---------------------------------------------------------------
-- PRUEBA MANUAL (opcional): corre esto después de instalar la función
-- de arriba, usando el id de un hilo real (con orden Confirmada o
-- Recibida), para confirmar que regresa el order_id y los servicios
-- esperados.
-- ---------------------------------------------------------------

-- SELECT public.get_thread_order('<pega-aquí-un-id-de-hilo-real>');
