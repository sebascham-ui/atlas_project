-- =====================================================
-- FASE 10 -- Gastos de oficina en el bot
-- Atlas Project -- 2026-07-25
--
-- Para qué sirve: agrega la categoría "Gastos de oficina" a la tabla
-- expense_categories (ya existente, sin tocar su estructura) para que el
-- bot de Telegram pueda registrar este tipo de gasto reutilizando 100%
-- el motor de formularios que ya usa gasolina/caseta/estacionamiento/
-- viáticos/refacción -- no hizo falta ninguna tabla nueva ni cambiar
-- log_expense.
--
-- is_operational = false a propósito: esta columna ya existe en
-- expense_categories y distingue gastos operativos de la flota (gasolina,
-- casetas, refacciones -- ligados a un vehículo/viaje) de gastos
-- administrativos (papelería, renta, servicios de oficina). Si prefieres
-- que cuente como operativo para tus reportes, dime y lo cambio con un
-- UPDATE de una línea.
-- =====================================================

INSERT INTO expense_categories (name, description, is_operational)
SELECT 'Gastos de oficina', 'Compras y pagos administrativos de oficina (no ligados a un vehículo o viaje)', false
WHERE NOT EXISTS (
    SELECT 1 FROM expense_categories WHERE name = 'Gastos de oficina'
);
