-- =====================================================
-- FASE 11 -- Nueva categoría de reporte de unidad: "Abolladuras o raspones"
-- Atlas Project -- 2026-07-25
--
-- Mismo patrón que 20260723_fase2_unidad_catalog.sql: se reutiliza
-- incidents/atlas.log_incident(), solo se agrega un código más al
-- catálogo INCIDENT_TYPE. Sin esta fila, el bot va a dejar elegir esta
-- opción normalmente, pero al final el registro va a fallar (log_incident
-- devuelve success:false porque el código no existe en el catálogo) --
-- por eso este script tiene que correr ANTES de que la opción se use en
-- producción.
--
-- Requiere haber corrido antes:
--   sql/migrations/20260723_fase2_incident_catalogs.sql
--   sql/migrations/20260723_fase2_unidad_catalog.sql
-- =====================================================

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('ABOLLADURA_RASPON', 'Abolladuras o raspones', 16)
) v(code, label, sort_order)
WHERE g.code = 'INCIDENT_TYPE'
AND NOT EXISTS (
    SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code
);
