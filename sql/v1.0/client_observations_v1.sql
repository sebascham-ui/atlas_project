-- =====================================================
-- OBSERVACIONES DE CLIENTE (client_observations)
-- Atlas Project -- 2026-07-22
--
-- Para qué sirve: capturar señales cualitativas sobre un cliente que se
-- van acumulando correo tras correo -- en qué hotel suele hospedarse, si
-- pide un chofer en específico, manías (ej. "no manejar rápido"),
-- cancelaciones, quejas, peticiones especiales recurrentes -- para que
-- con el tiempo alimenten dashboards reales (ej. "¿qué tan seguido
-- cancela este cliente?", "¿cuál es el hotel más frecuente?").
--
-- Por qué una tabla dedicada y no un campo de notas: cada observación
-- queda como una fila independiente, con fecha y origen (de qué mensaje
-- salió) -- así se puede contar, agrupar y graficar, y se conserva el
-- historial completo en vez de sobreescribir una sola nota cada vez.
-- =====================================================

--------------------------------------------------------
-- 1) CATÁLOGO: OBSERVATION_TYPE
--------------------------------------------------------

INSERT INTO catalog_groups(code, name)
SELECT 'OBSERVATION_TYPE', 'Client Observation Type'
WHERE NOT EXISTS (SELECT 1 FROM catalog_groups WHERE code = 'OBSERVATION_TYPE');

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (
VALUES
    ('PREFERRED_HOTEL', 'Hotel preferido', 1),
    ('PREFERRED_DRIVER', 'Chofer preferido', 2),
    ('DRIVING_PREFERENCE', 'Preferencia de manejo', 3),
    ('VEHICLE_PREFERENCE', 'Preferencia de vehículo', 4),
    ('CANCELLATION', 'Cancelación', 5),
    ('COMPLAINT', 'Queja', 6),
    ('COMPLIMENT', 'Cumplido', 7),
    ('SPECIAL_REQUEST', 'Petición especial recurrente', 8),
    ('PAYMENT_NOTE', 'Nota de pago/facturación', 9),
    ('GENERAL_NOTE', 'Observación general', 10)
) v(code, label, sort_order)
WHERE g.code = 'OBSERVATION_TYPE'
AND NOT EXISTS (SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code);


--------------------------------------------------------
-- 2) TABLA client_observations
--------------------------------------------------------

CREATE TABLE IF NOT EXISTS client_observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES accounts(id),
    person_id UUID REFERENCES people(id),
    observation_type_id INTEGER NOT NULL REFERENCES catalog_items(id),
    observation_text TEXT NOT NULL,
    source_message_id UUID REFERENCES conversation_messages(id),
    source_service_order_id UUID REFERENCES service_orders(id),
    ai_generated BOOLEAN NOT NULL DEFAULT true,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT client_observations_has_subject CHECK (
        account_id IS NOT NULL OR person_id IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_client_observations_account
    ON client_observations(account_id);
CREATE INDEX IF NOT EXISTS idx_client_observations_type
    ON client_observations(observation_type_id);


--------------------------------------------------------
-- 3) FUNCIÓN log_client_observation
--
-- Una función, una responsabilidad (ADS-001): solo registra una
-- observación. No decide si algo es o no observable -- eso lo decide la
-- IA de extracción antes de llamarla.
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.log_client_observation(
    p_account_id UUID,
    p_person_id UUID,
    p_observation_type_code TEXT,
    p_observation_text TEXT,
    p_source_message_id UUID DEFAULT NULL,
    p_source_service_order_id UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_observation_id UUID;
BEGIN
    INSERT INTO client_observations(
        account_id,
        person_id,
        observation_type_id,
        observation_text,
        source_message_id,
        source_service_order_id
    )
    VALUES(
        p_account_id,
        p_person_id,
        atlas.catalog('OBSERVATION_TYPE', p_observation_type_code),
        p_observation_text,
        p_source_message_id,
        p_source_service_order_id
    )
    RETURNING id
    INTO v_observation_id;

    RETURN v_observation_id;
END;
$function$;


CREATE OR REPLACE FUNCTION public.log_client_observation(
    p_account_id UUID,
    p_person_id UUID,
    p_observation_type_code TEXT,
    p_observation_text TEXT,
    p_source_message_id UUID DEFAULT NULL,
    p_source_service_order_id UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
AS $function$
SELECT atlas.log_client_observation(
    p_account_id, p_person_id, p_observation_type_code,
    p_observation_text, p_source_message_id, p_source_service_order_id
);
$function$;

--------------------------------------------------------
-- NOTA: esta tabla queda lista para usarse tanto en la recopilación
-- histórica de correos (siguiente paso) como en el flujo en vivo más
-- adelante, si en algún momento queremos que ATLAS detecte este tipo de
-- señales también en reservaciones nuevas, no solo en el histórico.
--
-- NOTA sobre "operation_fields": existe otra tabla en el esquema que
-- parece pensada para campos personalizados por entidad, pero no tiene
-- una tabla compañera que guarde valores ni ninguna función que la use
-- en este repositorio -- se dejó sin tocar porque no está claro su
-- propósito original; si más adelante se aclara, se puede reconsiderar
-- si client_observations debió apoyarse en ella en vez de ser una tabla
-- nueva.
--------------------------------------------------------
