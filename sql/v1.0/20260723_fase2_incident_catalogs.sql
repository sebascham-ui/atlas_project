-- =====================================================
-- FASE 2 -- Catálogos de incidentes + driver_id opcional
-- Atlas Project -- 2026-07-23
--
-- Igual que con gastos: driver_id se vuelve opcional para permitir
-- que un administrador registre un incidente de PRUEBA sin necesidad
-- de un chofer real (driver_id null + descripción prefijada
-- "[PRUEBA ADMIN] " desde el bot, mismo patrón que en expenses).
--
-- Los tres catálogos (INCIDENT_TYPE, INCIDENT_SEVERITY, INCIDENT_STATUS)
-- siguen el mismo patrón idempotente ya usado en
-- 20260716_add_message_catalogs.sql y 20260723_fase1_expense_categories_status.sql.
-- =====================================================

ALTER TABLE incidents ALTER COLUMN driver_id DROP NOT NULL;

-- INCIDENT_TYPE
INSERT INTO catalog_groups(code, name)
SELECT 'INCIDENT_TYPE', 'Tipo de Incidente'
WHERE NOT EXISTS (
    SELECT 1 FROM catalog_groups WHERE code = 'INCIDENT_TYPE'
);

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('ACCIDENTE', 'Accidente vehicular', 1),
    ('FALLA_MECANICA', 'Falla mecánica', 2),
    ('RETRASO', 'Retraso significativo', 3),
    ('PROBLEMA_PASAJERO', 'Problema con un pasajero', 4),
    ('OBJETO_OLVIDADO', 'Objeto olvidado en el vehículo', 5),
    ('MULTA', 'Multa de tránsito', 6),
    ('OTRO', 'Otro', 7)
) v(code, label, sort_order)
WHERE g.code = 'INCIDENT_TYPE'
AND NOT EXISTS (
    SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code
);

-- INCIDENT_SEVERITY
INSERT INTO catalog_groups(code, name)
SELECT 'INCIDENT_SEVERITY', 'Severidad de Incidente'
WHERE NOT EXISTS (
    SELECT 1 FROM catalog_groups WHERE code = 'INCIDENT_SEVERITY'
);

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('BAJA', 'Baja', 1),
    ('MEDIA', 'Media', 2),
    ('ALTA', 'Alta', 3),
    ('CRITICA', 'Crítica', 4)
) v(code, label, sort_order)
WHERE g.code = 'INCIDENT_SEVERITY'
AND NOT EXISTS (
    SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code
);

-- INCIDENT_STATUS
INSERT INTO catalog_groups(code, name)
SELECT 'INCIDENT_STATUS', 'Estatus de Incidente'
WHERE NOT EXISTS (
    SELECT 1 FROM catalog_groups WHERE code = 'INCIDENT_STATUS'
);

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('REPORTADO', 'Reportado', 1),
    ('EN_ATENCION', 'En atención', 2),
    ('RESUELTO', 'Resuelto', 3),
    ('CERRADO', 'Cerrado', 4)
) v(code, label, sort_order)
WHERE g.code = 'INCIDENT_STATUS'
AND NOT EXISTS (
    SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code
);
