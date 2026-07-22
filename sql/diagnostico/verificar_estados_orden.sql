-- =====================================================
-- DIAGNÓSTICO: ¿qué estados existen para las órdenes de servicio?
-- Atlas Project -- 2026-07-22
--
-- Cómo usarlo: entra al SQL Editor de Supabase (panel izquierdo,
-- ícono de base de datos) y pega este archivo completo. Ejecuta
-- cada bloque uno por uno (puedes seleccionar solo un bloque con
-- el mouse y correr solo ese) para ir viendo los resultados en
-- orden -- no hace falta que entiendas el SQL, solo lee los
-- resultados de cada tabla.
-- =====================================================


-- ---------------------------------------------------------------
-- PASO 1: ¿existe el grupo de catálogo "SERVICE_ORDER_STATUS"?
-- Si esta consulta regresa una fila, el grupo ya existe.
-- Si regresa vacío, significa que los estados todavía no se han
-- definido formalmente (aunque el código ya asuma que existen).
-- ---------------------------------------------------------------

SELECT id, code, name
FROM catalog_groups
WHERE code = 'SERVICE_ORDER_STATUS';


-- ---------------------------------------------------------------
-- PASO 2: ¿cuáles son los estados definidos dentro de ese grupo?
-- Esta es la respuesta a tu pregunta -- cada fila es un estado
-- posible para una orden de servicio (ej. RECEIVED, CONFIRMED,
-- CANCELLED, etc.), en el orden en que fueron pensados.
-- ---------------------------------------------------------------

SELECT
    i.code        AS codigo_estado,
    i.label       AS etiqueta,
    i.sort_order  AS orden
FROM catalog_items i
JOIN catalog_groups g ON g.id = i.group_id
WHERE g.code = 'SERVICE_ORDER_STATUS'
ORDER BY i.sort_order;


-- ---------------------------------------------------------------
-- PASO 3: confirmar que la tabla service_orders sí tiene una
-- columna de estado (status_id) y ver el resto de sus columnas,
-- por si hay algo más relevante para el seguimiento de conversaciones
-- (por ejemplo, si ya existe alguna columna de fecha de último
-- cambio de estado).
-- ---------------------------------------------------------------

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'atlas'
  AND table_name = 'service_orders'
ORDER BY ordinal_position;


-- ---------------------------------------------------------------
-- PASO 4 (opcional, solo informativo): cuántas órdenes reales hay
-- hoy en cada estado. Si todavía no has hecho pruebas reales, esto
-- puede regresar vacío o solo mostrar tus órdenes de prueba -- no
-- hay problema, es solo para tener contexto.
-- ---------------------------------------------------------------

SELECT
    i.code   AS estado,
    i.label  AS etiqueta,
    COUNT(so.id) AS cuantas_ordenes
FROM catalog_items i
JOIN catalog_groups g ON g.id = i.group_id
LEFT JOIN service_orders so ON so.status_id = i.id
WHERE g.code = 'SERVICE_ORDER_STATUS'
GROUP BY i.code, i.label, i.sort_order
ORDER BY i.sort_order;
