-- =====================================================
-- FASE 8 -- Catálogo de tiempos de traslado (rutas)
-- Atlas Project -- 2026-07-24
--
-- Para qué sirve: mover los tiempos de traslado que hoy viven fijos
-- dentro del código de la plantilla de correo (el objeto AIRPORT_TRAVEL
-- en "Ensamblar Correo con Plantilla") a una tabla real en la base --
-- así, agregar o corregir una ruta es editar una fila con SQL/Supabase,
-- no volver a tocar el código del flujo de n8n.
--
-- Sigue exactamente el mismo patrón que ya existe para pricing_rates
-- (sql/v1.0/pricing_engine_v1.sql): cada fila apunta a un concepto ya
-- existente en el catálogo PRICING_CONCEPT (mismos códigos que usa el
-- motor de precios -- AEROPUERTO_QRO, CIUDAD_LEON, etc.), así una ruta
-- y su precio comparten el mismo identificador, nunca hay que
-- mantenerlos sincronizados a mano por separado.
--
-- IMPORTANTE -- solo se siembran las rutas con tiempo YA CONFIRMADO por
-- Sebastián (ver conversación del proyecto, 2026-07-24). El resto de los
-- conceptos de PRICING_CONCEPT (CIUDAD_CDMX, CIUDAD_CELAYA,
-- CIUDAD_MORELIA, CIUDAD_SLP, LOCAL_SMA, SMA_HACIENDA, y los conceptos
-- por hora que no son una ruta punto a punto) se quedan sin fila aquí a
-- propósito -- mejor no tener dato que inventar uno. Cuando haya tiempos
-- reales para esos, se agregan con un INSERT nuevo, no hace falta volver
-- a correr todo este archivo.
--
-- PENDIENTE, avisado a Sebastián: "Guanajuato Capital" (90 min,
-- confirmado en la conversación) no tiene código en PRICING_CONCEPT --
-- ni aquí ni en pricing_rates existe todavía. Falta decidir si se agrega
-- como concepto nuevo (necesitaría también su propio precio en
-- pricing_rates, no solo el tiempo de traslado) antes de poder
-- sembrarlo aquí.
-- =====================================================

CREATE TABLE IF NOT EXISTS route_travel_times (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id INTEGER NOT NULL UNIQUE REFERENCES catalog_items(id),
    travel_minutes INTEGER NOT NULL,
    -- Minutos adicionales de margen recomendados (ej. tiempo de
    -- documentación/seguridad en aeropuerto). 0 para rutas que no lo
    -- necesitan (viajes dentro de ciudad, no aeropuerto).
    buffer_minutes INTEGER NOT NULL DEFAULT 0,
    -- Kilómetros esperados de la ruta principal (la más rápida, según
    -- Google Maps) -- referencia para comparar contra el kilometraje real
    -- que capture MyGeotab/Telegram y detectar gastos o desvíos fuera de
    -- lo normal. Nullable a propósito: no todos los conceptos lo tienen
    -- confirmado todavía, y no bloquea nada de lo que ya funciona (la hora
    -- recomendada de salida solo usa travel_minutes/buffer_minutes).
    expected_km NUMERIC(6,1),
    notes TEXT,
    active BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION atlas.touch_route_travel_time_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_route_travel_times_updated_at ON route_travel_times;
CREATE TRIGGER trg_route_travel_times_updated_at
  BEFORE UPDATE ON route_travel_times
  FOR EACH ROW
  EXECUTE FUNCTION atlas.touch_route_travel_time_updated_at();

-- Tiempos confirmados por Sebastián el 2026-07-24:
--   BJX/QRO (aeropuertos chicos): 90 min de traslado + 30 min de margen
--   CDMX (aeropuerto grande): 210 min (3h30) de traslado + 60 min de margen
--   Gdl./Cd. Gdl. (aeropuerto grande, reutiliza CIUDAD_GDL -- ver nota en
--     el código de la plantilla, no existe AEROPUERTO_GDL en el catálogo
--     de precios todavía): 270 min (4h30) de traslado + 60 min de margen
--   Ciudad de Querétaro (viaje dentro de la ciudad, no aeropuerto): 60 min,
--     sin margen adicional
--   Cd. de León (viaje dentro de la ciudad, no aeropuerto): 150 min (2h30),
--     sin margen adicional
--
-- expected_km se deja NULL en esta siembra a propósito: Sebastián está
-- comparando variantes de ruta en Google Maps (ej. para QRO, "ruta 01"
-- 91.4 km vs "ruta B" 83.5 km) y aún no elige cuál es la principal/default
-- -- mejor esperar esa decisión que sembrar un número que después haya
-- que corregir. Se puede actualizar fila por fila cuando esté listo, ej.:
--   UPDATE route_travel_times SET expected_km = 83.5
--     WHERE concept_id = (SELECT id FROM catalog_items WHERE code = 'AEROPUERTO_QRO');
INSERT INTO route_travel_times (concept_id, travel_minutes, buffer_minutes, notes)
SELECT concept.id, v.travel_minutes, v.buffer_minutes, v.notes
FROM (VALUES
    ('AEROPUERTO_QRO', 90, 30, 'Aeropuerto chico'),
    ('AEROPUERTO_BJX', 90, 30, 'Aeropuerto chico'),
    ('AEROPUERTO_CDMX', 210, 60, 'Aeropuerto grande'),
    ('CIUDAD_GDL', 270, 60, 'Aeropuerto grande -- reutiliza el concepto de ciudad porque no existe AEROPUERTO_GDL en PRICING_CONCEPT'),
    ('CIUDAD_QRO', 60, 0, 'Viaje dentro de ciudad, no aeropuerto'),
    ('CIUDAD_LEON', 150, 0, 'Viaje dentro de ciudad, no aeropuerto')
) v(concept_code, travel_minutes, buffer_minutes, notes)
JOIN catalog_groups cg ON cg.code = 'PRICING_CONCEPT'
JOIN catalog_items concept ON concept.group_id = cg.id AND concept.code = v.concept_code
WHERE NOT EXISTS (
    SELECT 1 FROM route_travel_times rtt WHERE rtt.concept_id = concept.id
);

-- Función que regresa TODAS las rutas activas en una sola llamada -- así
-- el flujo de n8n hace una sola consulta HTTP en vez de una por cada
-- concepto, mismo patrón que ya usan otras funciones del proyecto
-- (ej. quote_service_price).
CREATE OR REPLACE FUNCTION atlas.get_route_travel_times()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'concept_code', c.code,
      'travel_minutes', r.travel_minutes,
      'buffer_minutes', r.buffer_minutes,
      'expected_km', r.expected_km
  )), '[]'::jsonb)
  FROM route_travel_times r
  JOIN catalog_items c ON c.id = r.concept_id
  WHERE r.active = true;
$function$;

CREATE OR REPLACE FUNCTION public.get_route_travel_times()
RETURNS jsonb
LANGUAGE sql
AS $function$
  SELECT atlas.get_route_travel_times();
$function$;
