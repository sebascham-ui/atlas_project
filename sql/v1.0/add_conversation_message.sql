-- =====================================================
-- add_conversation_message
-- Verificado contra Supabase vía pg_get_functiondef el 2026-07-21.
-- Se documenta aquí porque existía desplegada en Supabase pero
-- nunca se había commiteado a GitHub.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.add_conversation_message(p_payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_message_id UUID;
BEGIN
    INSERT INTO conversation_messages(
        conversation_thread_id,
        channel_id,
        message_type_id,
        direction_id,
        sender_person_id,
        sender_name,
        sender_email,
        recipient,
        subject,
        body_text,
        body_html,
        sent_at,
        received_at,
        ai_generated,
        message_identifier,
        reply_to_identifier,
        raw_metadata
    )
    VALUES(
        (p_payload->>'conversation_thread_id')::UUID,
        atlas.catalog(
            'CHANNEL',
            p_payload->>'channel'
        ),
        atlas.catalog(
            'MESSAGE_TYPE',
            p_payload->>'message_type'
        ),
        atlas.catalog(
            'MESSAGE_DIRECTION',
            p_payload->>'direction'
        ),
        CASE
            WHEN COALESCE(
                p_payload->>'sender_person_id',
                ''
            )=''
            THEN NULL
            ELSE
                (p_payload->>'sender_person_id')::UUID
        END,
        p_payload->>'sender_name',
        p_payload->>'sender_email',
        p_payload->>'recipient',
        p_payload->>'subject',
        p_payload->>'body_text',
        p_payload->>'body_html',
        (p_payload->>'sent_at')::timestamptz,
        (p_payload->>'received_at')::timestamptz,
        COALESCE(
            (p_payload->>'ai_generated')::boolean,
            false
        ),
        p_payload->>'message_identifier',
        p_payload->>'reply_to_identifier',
        p_payload->'raw_metadata'
    )
    RETURNING id
    INTO v_message_id;
    RETURN v_message_id;
END;
$function$;


CREATE OR REPLACE FUNCTION public.add_conversation_message(p_payload jsonb)
 RETURNS uuid
 LANGUAGE sql
AS $function$
SELECT atlas.add_conversation_message(
    p_payload
);
$function$;
