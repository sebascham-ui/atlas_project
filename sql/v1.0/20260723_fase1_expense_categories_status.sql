-- =====================================================
-- FASE 1 -- Categorías de gasto y estatus de gasto
-- Atlas Project -- 2026-07-23
--
-- expense_categories NO usa catalog_items (es su propia tabla), así
-- que sus categorías se insertan directo ahí, idempotente por nombre.
-- Empezamos solo con las categorías que reporta un CHOFER desde el
-- bot -- tenencia/seguro/verificación (las registra administración,
-- no el chofer) se agregan cuando construya la Fase 3.
--
-- expenses.status_id sí usa catalog_items -- se crea el grupo nuevo
-- EXPENSE_STATUS.
-- =====================================================

INSERT INTO expense_categories(name, description, is_operational)
SELECT v.name, v.description, true
FROM (VALUES
    ('Gasolina', 'Combustible del vehículo'),
    ('Caseta', 'Peajes de autopista'),
    ('Estacionamiento', 'Pago de estacionamiento'),
    ('Comida', 'Alimentos del chofer en ruta'),
    ('Viáticos', 'Hospedaje u otros gastos de viaje del chofer'),
    ('Refacción', 'Refacción o reparación menor en ruta')
) v(name, description)
WHERE NOT EXISTS (
    SELECT 1 FROM expense_categories e WHERE e.name = v.name
);

INSERT INTO catalog_groups(code, name)
SELECT 'EXPENSE_STATUS', 'Estatus de Gasto'
WHERE NOT EXISTS (
    SELECT 1 FROM catalog_groups WHERE code = 'EXPENSE_STATUS'
);

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('REGISTRADO', 'Registrado', 1),
    ('APROBADO', 'Aprobado', 2),
    ('RECHAZADO', 'Rechazado', 3),
    ('REEMBOLSADO', 'Reembolsado', 4)
) v(code, label, sort_order)
WHERE g.code = 'EXPENSE_STATUS'
AND NOT EXISTS (
    SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code
);
