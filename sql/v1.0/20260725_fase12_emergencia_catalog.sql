-- =====================================================
-- FASE 12 -- Botón de Emergencia (SOS) para choferes
-- Atlas Project -- 2026-07-25
--
-- Mismo patrón que las fases 2 y 11: se reutiliza incidents/
-- atlas.log_incident(), solo se agrega un código nuevo al catálogo
-- INCIDENT_TYPE para poder distinguir un reporte de emergencia de un
-- reporte normal de unidad (útil para que, más adelante, el panel de
-- administración pueda filtrar/priorizar estos casos por separado).
--
-- La severidad ya existe (CRITICA, agregada en fase 2) -- no hace falta
-- tocar el catálogo INCIDENT_SEVERITY.
--
-- Sin esta fila, el botón de Emergencia sigue avisando de inmediato por
-- Telegram al canal de choferes (esa parte no depende de la base de
-- datos), pero el registro en la tabla incidents fallaría
-- silenciosamente (log_incident regresa success:false) -- por eso
-- conviene correr esto antes de usar el botón en producción, aunque no
-- es tan crítico como en fase 11 (el aviso por Telegram, que es lo que
-- de verdad importa en una emergencia, no depende de este script).
--
-- Requiere haber corrido antes:
--   sql/migrations/20260723_fase2_incident_catalogs.sql
-- =====================================================

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('EMERGENCIA', 'Emergencia / Auxilio', 17)
) v(code, label, sort_order)
WHERE g.code = 'INCIDENT_TYPE'
AND NOT EXISTS (
    SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code
);
