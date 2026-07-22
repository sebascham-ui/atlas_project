-- =====================================================
-- AGREGAR CÓDIGO 'CLOSED' AL CATÁLOGO CONVERSATION_STATUS
-- Atlas Project -- 2026-07-22
--
-- Por qué: la función find_or_create_conversation_thread() resuelve
-- status_id llamando a atlas.catalog('CONVERSATION_STATUS', <código>).
-- El flujo en vivo siempre usa 'OPEN' (ya existe en el catálogo). El
-- nuevo flujo de recopilación histórica necesita marcar los hilos
-- reconstruidos como 'CLOSED' (son conversaciones viejas ya resueltas,
-- no activas) -- pero ese código todavía no existía, así que la
-- función devolvía NULL y Postgres rechazaba el INSERT por la
-- restricción NOT NULL de status_id.
--
-- Esta migración es puramente ADITIVA: no toca 'OPEN' ni ningún otro
-- código existente, solo agrega 'CLOSED' si todavía no está.
-- =====================================================

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, 'CLOSED', 'Cerrada', 99
FROM catalog_groups g
WHERE g.code = 'CONVERSATION_STATUS'
AND NOT EXISTS (
    SELECT 1 FROM catalog_items i
    WHERE i.group_id = g.id AND i.code = 'CLOSED'
);
