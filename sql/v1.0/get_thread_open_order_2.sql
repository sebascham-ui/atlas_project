-- =====================================================
-- get_thread_open_order
-- Atlas Project -- 2026-07-22
--
-- Para qué sirve: dado un hilo de conversación (conversation_threads.id),
-- revisa si ese hilo YA tiene una orden de servicio ligada, y si esa orden
-- todavía está en estado "Recibida" (RECEIVED) -- es decir, nadie del
-- equipo la ha confirmado todavía.
--
-- Si encuentra una orden abierta, regresa {"order_id": "...", "folio": "..."}.
-- Si no hay ninguna orden ligada, o la que hay ya está Confirmada/Finalizada/
-- Cancelada, regresa NULL -- en ese caso Flujo 1 debe tratar el correo como
-- una reservación genuinamente nueva.
--
-- Por qué existe: sin esto, cada correo que un cliente responde dentro del
-- mismo hilo (por ejemplo, contestando la pregunta de datos faltantes)
-- generaba una ORDEN DUPLICADA en vez de reconocerse como continuación de
-- la misma reservación.
--
-- Cómo instalarlo: entra al SQL Editor de Supabase y pega este archivo
-- completo, luego ejecútalo. No modifica ninguna tabla existente, solo
-- agrega esta función nueva.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.get_thread_open_order(p_thread_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_order_id uuid;
    v_folio text;
    v_status_code text;
BEGIN
    SELECT so.id, so.folio, ci.code
      INTO v_order_id, v_folio, v_status_code
      FROM conversation_threads ct
      JOIN service_orders so ON so.id = ct.service_order_id
      JOIN catalog_items ci ON ci.id = so.status_id
     WHERE ct.id = p_thread_id
     LIMIT 1;

    -- Sin orden ligada al hilo, o la orden ligada ya no está "Recibida"
    -- (ya la confirmó/finalizó/canceló el equipo) -- en ambos casos, la
    -- solicitud nueva debe tratarse como una reservación aparte.
    IF v_order_id IS NULL OR v_status_code IS DISTINCT FROM 'RECEIVED' THEN
        RETURN NULL;
    END IF;

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'folio', v_folio
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_thread_open_order(p_thread_id uuid)
 RETURNS jsonb
 LANGUAGE sql
AS $function$
SELECT atlas.get_thread_open_order(p_thread_id);
$function$;


-- ---------------------------------------------------------------
-- PRUEBA MANUAL (opcional): corre esto después de instalar la función
-- de arriba, usando el id de un hilo real que ya tenga una orden en
-- "Recibida", para confirmar que regresa el order_id esperado.
-- ---------------------------------------------------------------

-- SELECT public.get_thread_open_order('<pega-aquí-un-id-de-hilo-real>');
