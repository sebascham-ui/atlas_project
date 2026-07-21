-- =====================================================
-- find_or_create_conversation_thread
-- Verificado contra Supabase vía pg_get_functiondef el 2026-07-21.
-- Se documenta aquí porque existía desplegada en Supabase pero
-- nunca se había commiteado a GitHub.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.find_or_create_conversation_thread(p_payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_thread_id uuid;
BEGIN
    SELECT id
      INTO v_thread_id
      FROM conversation_threads
     WHERE external_source = p_payload->'conversation'->>'external_source'
       AND external_thread_id = p_payload->'conversation'->>'external_thread_id'
     LIMIT 1;

    IF v_thread_id IS NULL THEN
        INSERT INTO conversation_threads (
            account_id,
            service_order_id,
            status_id,
            conversation_title,
            external_source,
            external_thread_id
        )
        VALUES (
            CASE
                WHEN coalesce(p_payload->'account'->>'id','')=''
                THEN NULL
                ELSE (p_payload->'account'->>'id')::uuid
            END,
            CASE
                WHEN coalesce(p_payload->'reservation'->>'service_order_id','')=''
                THEN NULL
                ELSE (p_payload->'reservation'->>'service_order_id')::uuid
            END,
            atlas.catalog(
                'CONVERSATION_STATUS',
                coalesce(
                    p_payload->'conversation'->>'status',
                    'OPEN'
                )
            ),
            p_payload->'conversation'->>'conversation_title',
            p_payload->'conversation'->>'external_source',
            p_payload->'conversation'->>'external_thread_id'
        )
        RETURNING id
        INTO v_thread_id;
    END IF;

    RETURN v_thread_id;
END;
$function$;


CREATE OR REPLACE FUNCTION public.find_or_create_conversation_thread(p_payload jsonb)
 RETURNS uuid
 LANGUAGE sql
AS $function$
SELECT atlas.find_or_create_conversation_thread(
    p_payload
);
$function$;
