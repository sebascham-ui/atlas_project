-- =====================================================
-- FASE 0 -- Alta de los 5 administradores
-- Atlas Project -- 2026-07-23
--
-- Requiere haber corrido antes:
--   sql/migrations/20260723_fase0_staff_roles_telegram.sql
--   sql/v1.0/staff_identity_v1.sql
--
-- Da de alta a los 5 administradores como people + rol ADMINISTRADOR
-- en staff_roles. Es idempotente (usa atlas.person(), que ya busca
-- por teléfono antes de crear, y atlas.add_staff_role(), que no
-- duplica un rol activo) -- se puede correr más de una vez sin
-- problema.
--
-- Los teléfonos se guardan en formato +52 sin espacios ni paréntesis
-- (ej. +527295564762), para que el match contra el número que
-- Telegram entrega al compartir contacto sea exacto. Cuando conecte
-- el flujo de "compartir mi contacto" del bot, voy a normalizar el
-- número que llegue de Telegram con el mismo criterio antes de
-- compararlo -- avisaré si en la práctica Telegram entrega un
-- formato distinto para ajustarlo.
--
-- OJO: todavía NO se llena telegram_chat_id aquí -- eso pasa cuando
-- cada persona abra el bot y comparta su contacto (así se vincula
-- con un número verificado por Telegram mismo, no por lo que alguien
-- escriba a mano).
-- =====================================================

DO $$
DECLARE
    v_person_id UUID;
BEGIN

    -- Sebastián Chávez Méndez
    v_person_id := atlas.person(jsonb_build_object(
        'given_names', 'Sebastián',
        'last_name', 'Chávez Méndez',
        'phone', '+527295564762'
    ));
    PERFORM atlas.add_staff_role(v_person_id, 'ADMINISTRADOR');

    -- Jorge Antonio Chávez
    v_person_id := atlas.person(jsonb_build_object(
        'given_names', 'Jorge Antonio',
        'last_name', 'Chávez',
        'phone', '+524151534433'
    ));
    PERFORM atlas.add_staff_role(v_person_id, 'ADMINISTRADOR');

    -- Francisca Méndez Chávez
    v_person_id := atlas.person(jsonb_build_object(
        'given_names', 'Francisca',
        'last_name', 'Méndez Chávez',
        'phone', '+524151534434'
    ));
    PERFORM atlas.add_staff_role(v_person_id, 'ADMINISTRADOR');

    -- Maritza Chávez Méndez
    v_person_id := atlas.person(jsonb_build_object(
        'given_names', 'Maritza',
        'last_name', 'Chávez Méndez',
        'phone', '+524151054985'
    ));
    PERFORM atlas.add_staff_role(v_person_id, 'ADMINISTRADOR');

    -- Miguel Chávez Méndez
    v_person_id := atlas.person(jsonb_build_object(
        'given_names', 'Miguel',
        'last_name', 'Chávez Méndez',
        'phone', '+524151534084'
    ));
    PERFORM atlas.add_staff_role(v_person_id, 'ADMINISTRADOR');

END $$;
