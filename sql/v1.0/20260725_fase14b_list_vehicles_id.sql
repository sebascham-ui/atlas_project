-- =====================================================
-- FASE 14b -- Agregar el id (UUID) a list_active_vehicles
-- Atlas Project -- 2026-07-25
--
-- Para qué sirve: el selector de "Asignar unidad" (Acciones Rápidas del
-- bot de Admin) necesita el UUID de la unidad para llamar assign_service,
-- igual que el selector de chofer usa el UUID del chofer
-- (list_active_drivers ya devuelve id). list_active_vehicles (Fase 9)
-- solo devolvía 'code' y 'label' -- este cambio le AGREGA 'id', sin quitar
-- ni cambiar nada de lo que ya devolvía.
--
-- Es puramente aditivo: el flujo del chofer (reporte de falla, kilometraje,
-- gasolina, lavacoches) lee 'label' y 'code', que siguen igual -- no se ve
-- afectado. Solo se agrega una llave nueva al JSON.
--
-- Requiere haber corrido antes:
--   sql/migrations/20260724_fase9_unidades_en_bot.sql (versión original)
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.list_active_vehicles()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  SELECT jsonb_build_object('vehicles', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', v.id,
        'code', v.internal_code,
        'label', v.internal_code || ' · ' || COALESCE(v.brand,'') ||
                 CASE WHEN v.model IS NOT NULL THEN ' ' || v.model ELSE '' END ||
                 CASE WHEN v.license_plate IS NOT NULL THEN ' (' || v.license_plate || ')' ELSE '' END
      )
      ORDER BY v.internal_code
  ), '[]'::jsonb))
  FROM vehicles v
  JOIN catalog_items st ON st.id = v.status_id
  WHERE st.code = 'ACTIVE';
$function$;
