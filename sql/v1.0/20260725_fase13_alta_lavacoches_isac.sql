-- =====================================================
-- FASE 13 -- Alta de Isaac (lavacoches) como personal con acceso al bot
-- Atlas Project -- 2026-07-25
--
-- Mismo patrón que sql/v1.0/seed_administradores_v1.sql: usa
-- atlas.person() (ya deduplica por teléfono, no crea duplicados si se
-- corre más de una vez) + atlas.add_staff_role() (tampoco duplica un
-- rol activo). El catálogo STAFF_ROLE con el código LAVACOCHES ya
-- existía desde la fase 0 -- no hizo falta agregar nada nuevo ahí.
--
-- Isaac todavía no tiene apellido registrado -- se deja NULL por ahora
-- (la tabla people lo permite) y se actualiza después con un UPDATE de
-- una línea cuando Sebastián lo confirme:
--
--   UPDATE people SET last_name = '<apellido>'
--   WHERE phone = '+524153020397';
--
-- Requiere haber corrido antes:
--   sql/migrations/20260723_fase0_staff_roles_telegram.sql
--   sql/v1.0/staff_identity_v1.sql
--   sql/v1.0/person_phone_dedup_v1.sql
-- =====================================================

DO $$
DECLARE
    v_person_id UUID;
BEGIN

    -- Isaac (lavacoches) -- apellido pendiente
    v_person_id := atlas.person(jsonb_build_object(
        'given_names', 'Isaac',
        'phone', '+524153020397'
    ));
    PERFORM atlas.add_staff_role(v_person_id, 'LAVACOCHES');

END $$;
