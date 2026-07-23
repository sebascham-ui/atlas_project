-- =====================================================
-- FASE 1 -- Alta del primer chofer real: Gregorio Sierra
-- Atlas Project -- 2026-07-23
--
-- Requiere haber corrido antes: driver_registration_v1.sql
--
-- Solo se conocen nombre y teléfono por ahora -- licencia, fecha de
-- contratación y tarifa quedan en blanco, se pueden completar después
-- sin volver a correr esto (register_driver es idempotente).
-- =====================================================

SELECT atlas.register_driver(jsonb_build_object(
    'given_names', 'Gregorio',
    'last_name', 'Sierra',
    'phone', '+524151006023'
));
