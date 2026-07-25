-- =====================================================
-- FASE 7 -- Tipo de cambio USD/MXN (para mostrar precio en dólares)
-- Atlas Project -- 2026-07-24
--
-- Tabla mínima, un solo propósito: guardar un tipo de cambio que TÚ
-- actualizas manualmente cuando quieras (no se consulta ningún servicio
-- externo -- decisión explícita para no depender de una API que se puede
-- caer o tardar, ver conversación del proyecto).
--
-- Arranca en 18.00 según lo que confirmaste. Para actualizarlo más
-- adelante, no hace falta volver a correr este archivo -- basta con:
--
--   UPDATE atlas.exchange_rates SET rate = 18.75 WHERE currency_pair = 'USD_MXN';
--
-- (el campo updated_at se actualiza solo, por el trigger de abajo).
-- =====================================================

CREATE TABLE IF NOT EXISTS atlas.exchange_rates (
  currency_pair TEXT PRIMARY KEY,
  rate NUMERIC(10,4) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION atlas.touch_exchange_rate_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_exchange_rates_updated_at ON atlas.exchange_rates;
CREATE TRIGGER trg_exchange_rates_updated_at
  BEFORE UPDATE ON atlas.exchange_rates
  FOR EACH ROW
  EXECUTE FUNCTION atlas.touch_exchange_rate_updated_at();

INSERT INTO atlas.exchange_rates (currency_pair, rate)
VALUES ('USD_MXN', 18.00)
ON CONFLICT (currency_pair) DO NOTHING;
