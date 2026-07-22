-- =====================================================
-- MOTOR DE PRECIOS (v1)
-- Atlas Project -- 2026-07-22
--
-- Para qué sirve: catálogo de precios y pagos a chofer, importado del
-- Excel "Catálogo Precios Pagos Servicios" que Sebastián compartió,
-- para que el sistema pueda calcular el costo de un servicio y sugerir
-- qué unidad (vehículo) asignar, sin que el staff tenga que buscarlo
-- a mano cada vez.
--
-- Decisiones de diseño (confirmadas con el usuario):
-- - La unidad (SEDAN/SUV/MAXIVAN) se asigna automáticamente según
--   pasajeros/equipaje -- el staff puede cambiarla si el viaje lo amerita.
-- - Las tarifas especiales de socios (Villa Santa Mónica, La Valise, JAQ)
--   solo se aplican si la CUENTA ya está marcada con ese nivel de precio
--   en Supabase -- no se detecta automáticamente por el contenido del
--   correo. Por default, toda cuenta nueva es PUBLICO_GENERAL.
-- - "CLIENTES_ESPECIALES" es un RANGO de negociación manual para otros
--   hoteles (varios precios del inicial al piso por volumen) -- se carga
--   como referencia para el staff, pero el flujo automatizado NUNCA la
--   selecciona sola.
-- - El precio calculado NO se muestra al cliente en el correo automático
--   todavía -- solo queda visible para el staff (alerta interna / campos
--   en la orden). Cuando el negocio tenga confianza en los cálculos, se
--   puede mostrar también al cliente.
--
-- Cómo instalarlo: entra al SQL Editor de Supabase y pega este archivo
-- completo, luego ejecútalo. Es seguro volver a correrlo (las partes de
-- catálogo e inserción de datos no duplican filas ya existentes).
-- =====================================================


--------------------------------------------------------
-- 1) GRUPOS Y VALORES DE CATÁLOGO NUEVOS
--------------------------------------------------------

INSERT INTO catalog_groups(code, name)
SELECT 'PRICING_CONCEPT', 'Pricing Concept (destino/servicio facturable)'
WHERE NOT EXISTS (SELECT 1 FROM catalog_groups WHERE code = 'PRICING_CONCEPT');

INSERT INTO catalog_groups(code, name)
SELECT 'PRICING_CLIENT_TIER', 'Pricing Client Tier'
WHERE NOT EXISTS (SELECT 1 FROM catalog_groups WHERE code = 'PRICING_CLIENT_TIER');

INSERT INTO catalog_groups(code, name)
SELECT 'VEHICLE_TYPE', 'Vehicle Type'
WHERE NOT EXISTS (SELECT 1 FROM catalog_groups WHERE code = 'VEHICLE_TYPE');


INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (
VALUES
    ('AEROPUERTO_BJX', 'Aeropuerto BJX (León)', 1),
    ('AEROPUERTO_CDMX', 'Aeropuerto CDMX', 2),
    ('AEROPUERTO_QRO', 'Aeropuerto QRO (Querétaro)', 3),
    ('CIUDAD_CDMX', 'Ciudad de México', 4),
    ('CIUDAD_CELAYA', 'Celaya', 5),
    ('CIUDAD_GDL', 'Guadalajara', 6),
    ('CIUDAD_LEON', 'León', 7),
    ('CIUDAD_MORELIA', 'Morelia', 8),
    ('CIUDAD_QRO', 'Querétaro (ciudad)', 9),
    ('CIUDAD_SLP', 'San Luis Potosí', 10),
    ('LOCAL_SMA', 'Local San Miguel de Allende', 11),
    ('SMA_HACIENDA', 'Hacienda (San Miguel de Allende)', 12),
    ('HORA_TOUR', 'Tour por hora', 13),
    ('HORA_DE_ESPERA', 'Hora de espera', 14),
    ('HR_EXTRA_SERVICIO', 'Hora extra de servicio', 15),
    ('ESPERA_CADA_4_HRS', 'Espera cada 4 horas', 16),
    ('ESPERA_CON_PERNOCTACION', 'Espera con pernoctación', 17)
) v(code, label, sort_order)
WHERE g.code = 'PRICING_CONCEPT'
AND NOT EXISTS (SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code);


INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (
VALUES
    ('PUBLICO_GENERAL', 'Público General', 1),
    ('VILLA_SANTA_MONICA', 'Villa Santa Mónica', 2),
    ('LA_VALISE', 'La Valise', 3),
    ('JAQ', 'JAQ', 4),
    ('CLIENTES_ESPECIALES', 'Clientes Especiales (rango de negociación)', 5)
) v(code, label, sort_order)
WHERE g.code = 'PRICING_CLIENT_TIER'
AND NOT EXISTS (SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code);


INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (
VALUES
    ('SEDAN', 'Sedán', 1),
    ('SUV', 'SUV', 2),
    ('MAXIVAN', 'Maxivan', 3)
) v(code, label, sort_order)
WHERE g.code = 'VEHICLE_TYPE'
AND NOT EXISTS (SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code);


--------------------------------------------------------
-- 2) TABLA pricing_rates
--------------------------------------------------------

-- Nota: catalog_items.id es INTEGER, no UUID -- es la única excepción
-- confirmada a la convención "UUID everywhere" del proyecto (Supabase lo
-- reportó al fallar la primera versión de este archivo). Por eso las
-- columnas que apuntan a catalog_items(id) abajo son INTEGER.
CREATE TABLE IF NOT EXISTS pricing_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id INTEGER NOT NULL REFERENCES catalog_items(id),
    client_tier_id INTEGER NOT NULL REFERENCES catalog_items(id),
    vehicle_type_id INTEGER NOT NULL REFERENCES catalog_items(id),
    price_day NUMERIC(10,2),
    price_night NUMERIC(10,2),
    driver_pay_day NUMERIC(10,2),
    driver_pay_night NUMERIC(10,2),
    driver_pay_round_trip NUMERIC(10,2),
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pricing_rates_lookup
    ON pricing_rates(concept_id, client_tier_id, vehicle_type_id);


--------------------------------------------------------
-- 3) IMPORTAR LAS 204 FILAS DEL EXCEL
-- (concept_code, client_tier_code, vehicle_code, price_day, price_night,
--  driver_pay_day, driver_pay_night, driver_pay_round_trip, active)
--------------------------------------------------------

INSERT INTO pricing_rates(
    concept_id, client_tier_id, vehicle_type_id,
    price_day, price_night, driver_pay_day, driver_pay_night, driver_pay_round_trip, active
)
SELECT
    concept.id, tier.id, vehicle.id,
    v.price_day, v.price_night, v.pay_day, v.pay_night, v.pay_rt, v.active
FROM (
VALUES
('AEROPUERTO_BJX','PUBLICO_GENERAL','SEDAN',2200,2500,420,520,0,true),
('AEROPUERTO_CDMX','PUBLICO_GENERAL','SEDAN',6500,6800,960,1060,1560,true),
('AEROPUERTO_QRO','PUBLICO_GENERAL','SEDAN',2200,2500,420,520,0,true),
('CIUDAD_CDMX','PUBLICO_GENERAL','SEDAN',6500,6800,960,1060,0,true),
('CIUDAD_CELAYA','PUBLICO_GENERAL','SEDAN',1700,2000,360,410,0,true),
('CIUDAD_GDL','PUBLICO_GENERAL','SEDAN',7500,7800,1320,1420,2220,true),
('CIUDAD_LEON','PUBLICO_GENERAL','SEDAN',2700,3000,540,590,0,true),
('CIUDAD_MORELIA','PUBLICO_GENERAL','SEDAN',4500,NULL,720,820,1320,true),
('CIUDAD_QRO','PUBLICO_GENERAL','SEDAN',2000,2300,420,520,0,true),
('CIUDAD_SLP','PUBLICO_GENERAL','SEDAN',2700,3000,600,700,1100,true),
('HORA_DE_ESPERA','PUBLICO_GENERAL','SEDAN',650,650,200,200,200,true),
('ESPERA_CON_PERNOCTACION','PUBLICO_GENERAL','SEDAN',0,0,400,400,400,true),
('HORA_TOUR','PUBLICO_GENERAL','SEDAN',650,650,180,0,0,true),
('HR_EXTRA_SERVICIO','PUBLICO_GENERAL','SEDAN',650,650,144,174,0,true),
('LOCAL_SMA','PUBLICO_GENERAL','SEDAN',500,500,180,230,0,true),
('SMA_HACIENDA','PUBLICO_GENERAL','SEDAN',1000,1000,240,290,0,true),
('AEROPUERTO_BJX','PUBLICO_GENERAL','SUV',3200,3500,420,520,0,true),
('AEROPUERTO_CDMX','PUBLICO_GENERAL','SUV',7500,7800,960,1060,1560,true),
('AEROPUERTO_QRO','PUBLICO_GENERAL','SUV',3200,3500,420,520,0,true),
('CIUDAD_CDMX','PUBLICO_GENERAL','SUV',7500,7800,960,1060,0,true),
('CIUDAD_CELAYA','PUBLICO_GENERAL','SUV',2400,NULL,360,410,0,true),
('CIUDAD_GDL','PUBLICO_GENERAL','SUV',9000,9000,1320,1420,2220,true),
('CIUDAD_LEON','PUBLICO_GENERAL','SUV',3800,4000,540,590,0,true),
('CIUDAD_MORELIA','PUBLICO_GENERAL','SUV',5500,NULL,720,820,1320,true),
('CIUDAD_QRO','PUBLICO_GENERAL','SUV',3000,3300,420,520,0,true),
('CIUDAD_SLP','PUBLICO_GENERAL','SUV',3700,4000,600,700,1100,true),
('HORA_DE_ESPERA','PUBLICO_GENERAL','SUV',650,650,200,200,200,true),
('ESPERA_CON_PERNOCTACION','PUBLICO_GENERAL','SUV',0,0,400,400,400,true),
('HORA_TOUR','PUBLICO_GENERAL','SUV',750,750,180,0,0,true),
('HR_EXTRA_SERVICIO','PUBLICO_GENERAL','SUV',650,650,144,174,0,true),
('LOCAL_SMA','PUBLICO_GENERAL','SUV',1000,1000,180,230,0,true),
('SMA_HACIENDA','PUBLICO_GENERAL','SUV',1800,1800,240,290,0,true),
('AEROPUERTO_BJX','PUBLICO_GENERAL','MAXIVAN',3900,4200,420,520,0,true),
('AEROPUERTO_CDMX','PUBLICO_GENERAL','MAXIVAN',9000,9500,960,1060,1560,true),
('AEROPUERTO_QRO','PUBLICO_GENERAL','MAXIVAN',3900,4200,420,520,0,true),
('CIUDAD_CDMX','PUBLICO_GENERAL','MAXIVAN',9000,9500,960,1060,0,true),
('CIUDAD_CELAYA','PUBLICO_GENERAL','MAXIVAN',3500,NULL,360,410,0,true),
('CIUDAD_GDL','PUBLICO_GENERAL','MAXIVAN',9500,9500,1320,1420,2220,true),
('CIUDAD_LEON','PUBLICO_GENERAL','MAXIVAN',4700,5000,540,590,0,true),
('CIUDAD_MORELIA','PUBLICO_GENERAL','MAXIVAN',5500,NULL,720,820,1320,true),
('CIUDAD_QRO','PUBLICO_GENERAL','MAXIVAN',3900,4200,420,520,0,true),
('CIUDAD_SLP','PUBLICO_GENERAL','MAXIVAN',4700,5000,600,700,1100,true),
('HORA_DE_ESPERA','PUBLICO_GENERAL','MAXIVAN',700,700,200,200,200,true),
('ESPERA_CON_PERNOCTACION','PUBLICO_GENERAL','MAXIVAN',0,0,400,400,400,true),
('HORA_TOUR','PUBLICO_GENERAL','MAXIVAN',900,900,180,0,0,true),
('HR_EXTRA_SERVICIO','PUBLICO_GENERAL','MAXIVAN',700,700,144,174,0,true),
('LOCAL_SMA','PUBLICO_GENERAL','MAXIVAN',1300,1300,180,230,0,true),
('SMA_HACIENDA','PUBLICO_GENERAL','MAXIVAN',2000,2000,240,290,0,true),
('AEROPUERTO_BJX','VILLA_SANTA_MONICA','SEDAN',2157.6,2657.6,420,520,0,true),
('AEROPUERTO_CDMX','VILLA_SANTA_MONICA','SEDAN',6878.8,7878.8,960,1060,1560,true),
('AEROPUERTO_QRO','VILLA_SANTA_MONICA','SEDAN',2157.6,2657.6,420,520,0,true),
('CIUDAD_CDMX','VILLA_SANTA_MONICA','SEDAN',6878.8,7878.8,960,1060,0,true),
('CIUDAD_CELAYA','VILLA_SANTA_MONICA','SEDAN',1700,1700,360,410,0,true),
('CIUDAD_GDL','VILLA_SANTA_MONICA','SEDAN',6700,6700,1320,1420,2220,true),
('CIUDAD_LEON','VILLA_SANTA_MONICA','SEDAN',2600,2600,540,590,0,true),
('CIUDAD_MORELIA','VILLA_SANTA_MONICA','SEDAN',4500,4500,720,820,1320,true),
('CIUDAD_QRO','VILLA_SANTA_MONICA','SEDAN',2157.6,2657.6,420,520,0,true),
('CIUDAD_SLP','VILLA_SANTA_MONICA','SEDAN',NULL,NULL,600,700,1100,true),
('ESPERA_CADA_4_HRS','VILLA_SANTA_MONICA','SEDAN',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','VILLA_SANTA_MONICA','SEDAN',NULL,NULL,400,400,400,true),
('HORA_TOUR','VILLA_SANTA_MONICA','SEDAN',696,696,180,0,0,true),
('HR_EXTRA_SERVICIO','VILLA_SANTA_MONICA','SEDAN',696,696,144,174,0,true),
('LOCAL_SMA','VILLA_SANTA_MONICA','SEDAN',250,250,180,230,0,true),
('SMA_HACIENDA','VILLA_SANTA_MONICA','SEDAN',696,696,240,290,0,true),
('AEROPUERTO_BJX','VILLA_SANTA_MONICA','SUV',3306,3806,420,520,0,true),
('AEROPUERTO_CDMX','VILLA_SANTA_MONICA','SUV',9187.2,10187.2,960,1060,1560,true),
('AEROPUERTO_QRO','VILLA_SANTA_MONICA','SUV',3306,3806,420,520,0,true),
('CIUDAD_CDMX','VILLA_SANTA_MONICA','SUV',9187.2,10187.2,960,1060,0,true),
('CIUDAD_CELAYA','VILLA_SANTA_MONICA','SUV',2400,2400,360,410,0,true),
('CIUDAD_GDL','VILLA_SANTA_MONICA','SUV',10187.2,11187.2,1320,1420,2220,true),
('CIUDAD_LEON','VILLA_SANTA_MONICA','SUV',4083.2,4583.2,540,590,0,true),
('CIUDAD_MORELIA','VILLA_SANTA_MONICA','SUV',5700,6100,720,820,1320,true),
('CIUDAD_QRO','VILLA_SANTA_MONICA','SUV',3306,3806,420,520,0,true),
('CIUDAD_SLP','VILLA_SANTA_MONICA','SUV',NULL,NULL,600,700,1100,true),
('ESPERA_CADA_4_HRS','VILLA_SANTA_MONICA','SUV',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','VILLA_SANTA_MONICA','SUV',NULL,NULL,400,400,400,true),
('HORA_TOUR','VILLA_SANTA_MONICA','SUV',1392,1392,180,0,0,true),
('HR_EXTRA_SERVICIO','VILLA_SANTA_MONICA','SUV',1392,1392,144,174,0,true),
('LOCAL_SMA','VILLA_SANTA_MONICA','SUV',650,650,180,230,0,true),
('SMA_HACIENDA','VILLA_SANTA_MONICA','SUV',850,850,240,290,0,true),
('AEROPUERTO_BJX','VILLA_SANTA_MONICA','MAXIVAN',4083.2,4583.2,420,520,0,true),
('AEROPUERTO_CDMX','VILLA_SANTA_MONICA','MAXIVAN',NULL,NULL,960,1060,1560,true),
('AEROPUERTO_QRO','VILLA_SANTA_MONICA','MAXIVAN',4083.2,4583.2,420,520,0,true),
('CIUDAD_CDMX','VILLA_SANTA_MONICA','MAXIVAN',12122,13122,960,1060,0,true),
('CIUDAD_CELAYA','VILLA_SANTA_MONICA','MAXIVAN',4083.2,4583.2,360,410,0,true),
('CIUDAD_GDL','VILLA_SANTA_MONICA','MAXIVAN',9100,9800,1320,1420,2220,true),
('CIUDAD_LEON','VILLA_SANTA_MONICA','MAXIVAN',4400,4400,540,590,0,true),
('CIUDAD_MORELIA','VILLA_SANTA_MONICA','MAXIVAN',NULL,NULL,720,820,1320,true),
('CIUDAD_QRO','VILLA_SANTA_MONICA','MAXIVAN',4083.2,4583.2,420,520,0,true),
('CIUDAD_SLP','VILLA_SANTA_MONICA','MAXIVAN',NULL,NULL,600,700,1100,true),
('ESPERA_CADA_4_HRS','VILLA_SANTA_MONICA','MAXIVAN',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','VILLA_SANTA_MONICA','MAXIVAN',NULL,NULL,400,400,400,true),
('HORA_TOUR','VILLA_SANTA_MONICA','MAXIVAN',1740,1740,180,0,0,true),
('HR_EXTRA_SERVICIO','VILLA_SANTA_MONICA','MAXIVAN',1740,1740,144,174,0,true),
('LOCAL_SMA','VILLA_SANTA_MONICA','MAXIVAN',1200,1700,180,230,0,true),
('SMA_HACIENDA','VILLA_SANTA_MONICA','MAXIVAN',1800,2600,240,290,0,true),
('AEROPUERTO_BJX','JAQ','SEDAN',1550.016,1550.016,420,520,0,true),
('AEROPUERTO_CDMX','JAQ','SEDAN',4506.9696,4506.9696,960,1060,1560,true),
('AEROPUERTO_QRO','JAQ','SEDAN',1550.016,1550.016,420,520,0,true),
('CIUDAD_CDMX','JAQ','SEDAN',4506.9696,4506.9696,960,1060,0,true),
('CIUDAD_CELAYA','JAQ','SEDAN',1550.016,1550.016,360,410,0,true),
('CIUDAD_GDL','JAQ','SEDAN',6000,6000,1320,1420,2220,true),
('CIUDAD_LEON','JAQ','SEDAN',2026,2026,540,590,0,true),
('CIUDAD_MORELIA','JAQ','SEDAN',3600,3600,720,820,1320,true),
('CIUDAD_QRO','JAQ','SEDAN',1788.48,1788.48,420,520,0,true),
('CIUDAD_SLP','JAQ','SEDAN',2384.004,2384.004,600,700,1100,true),
('ESPERA_CADA_4_HRS','JAQ','SEDAN',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','JAQ','SEDAN',NULL,NULL,400,400,400,true),
('HORA_TOUR','JAQ','SEDAN',476.928,476.928,180,0,0,true),
('HR_EXTRA_SERVICIO','JAQ','SEDAN',476.928,476.928,144,174,0,true),
('LOCAL_SMA','JAQ','SEDAN',476.928,476.928,180,230,0,true),
('SMA_HACIENDA','JAQ','SEDAN',1000,1000,240,290,0,true),
('AEROPUERTO_BJX','JAQ','SUV',2146.176,2146.176,420,520,0,true),
('AEROPUERTO_CDMX','JAQ','SUV',5758.9056,5758.9056,960,1060,1560,true),
('AEROPUERTO_QRO','JAQ','SUV',2146.176,2146.176,420,520,0,true),
('CIUDAD_CDMX','JAQ','SUV',5758.9056,5758.9056,960,1060,0,true),
('CIUDAD_CELAYA','JAQ','SUV',2146.176,2146.176,360,410,0,true),
('CIUDAD_GDL','JAQ','SUV',7000,7000,1320,1420,2220,true),
('CIUDAD_LEON','JAQ','SUV',3338.496,3338.496,540,590,0,true),
('CIUDAD_MORELIA','JAQ','SUV',4300,4300,720,820,1320,true),
('CIUDAD_QRO','JAQ','SUV',2384.6400000000003,2384.6400000000003,420,520,0,true),
('CIUDAD_SLP','JAQ','SUV',2980.8,2980.8,600,700,1100,true),
('ESPERA_CADA_4_HRS','JAQ','SUV',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','JAQ','SUV',NULL,NULL,400,400,400,true),
('HORA_TOUR','JAQ','SUV',596.1600000000001,596.1600000000001,180,0,0,true),
('HR_EXTRA_SERVICIO','JAQ','SUV',596.1600000000001,596.1600000000001,144,174,0,true),
('LOCAL_SMA','JAQ','SUV',596.1600000000001,596.1600000000001,180,230,0,true),
('SMA_HACIENDA','JAQ','SUV',1400,1400,240,290,0,true),
('AEROPUERTO_BJX','JAQ','MAXIVAN',2503.872,2503.872,420,520,0,true),
('AEROPUERTO_CDMX','JAQ','MAXIVAN',7010.8416,7010.8416,960,1060,1560,true),
('AEROPUERTO_QRO','JAQ','MAXIVAN',2503.872,2503.872,420,520,0,true),
('CIUDAD_CDMX','JAQ','MAXIVAN',7010.8416,7010.8416,960,1060,0,true),
('CIUDAD_CELAYA','JAQ','MAXIVAN',2503.872,2503.872,360,410,0,true),
('CIUDAD_GDL','JAQ','MAXIVAN',8000,8000,1320,1420,2220,true),
('CIUDAD_LEON','JAQ','MAXIVAN',4173.12,4173.12,540,590,0,true),
('CIUDAD_MORELIA','JAQ','MAXIVAN',4900,4900,720,820,1320,true),
('CIUDAD_QRO','JAQ','MAXIVAN',2742.3360000000002,2742.3360000000002,420,520,0,true),
('CIUDAD_SLP','JAQ','MAXIVAN',3780,3780,600,700,1100,true),
('ESPERA_CADA_4_HRS','JAQ','MAXIVAN',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','JAQ','MAXIVAN',NULL,NULL,400,400,400,true),
('HORA_TOUR','JAQ','MAXIVAN',834.624,834.624,180,0,0,true),
('HR_EXTRA_SERVICIO','JAQ','MAXIVAN',834.624,834.624,144,174,0,true),
('LOCAL_SMA','JAQ','MAXIVAN',834.624,834.624,180,230,0,true),
('SMA_HACIENDA','JAQ','MAXIVAN',1400,1400,240,290,0,true),
('AEROPUERTO_BJX','LA_VALISE','SEDAN',2200,2200,420,520,0,true),
('AEROPUERTO_CDMX','LA_VALISE','SEDAN',6400,6400,960,1060,1560,true),
('AEROPUERTO_QRO','LA_VALISE','SEDAN',2200,2200,420,520,0,true),
('CIUDAD_CDMX','LA_VALISE','SEDAN',6400,6400,960,1060,0,true),
('CIUDAD_CELAYA','LA_VALISE','SEDAN',2200,2200,360,410,0,true),
('CIUDAD_GDL','LA_VALISE','SEDAN',7772,7772,1320,1420,2220,true),
('CIUDAD_LEON','LA_VALISE','SEDAN',2800,2800,540,590,0,true),
('CIUDAD_MORELIA','LA_VALISE','SEDAN',5220,5220,720,820,1320,true),
('CIUDAD_QRO','LA_VALISE','SEDAN',2200,2200,420,520,0,true),
('CIUDAD_SLP','LA_VALISE','SEDAN',NULL,NULL,600,700,1100,true),
('ESPERA_CADA_4_HRS','LA_VALISE','SEDAN',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','LA_VALISE','SEDAN',NULL,NULL,400,400,400,true),
('HORA_TOUR','LA_VALISE','SEDAN',765,765,180,0,0,true),
('HR_EXTRA_SERVICIO','LA_VALISE','SEDAN',600,600,144,174,0,true),
('LOCAL_SMA','LA_VALISE','SEDAN',600,600,180,230,0,true),
('SMA_HACIENDA','LA_VALISE','SEDAN',600,600,240,290,0,true),
('AEROPUERTO_BJX','LA_VALISE','SUV',3200,3200,420,520,0,true),
('AEROPUERTO_CDMX','LA_VALISE','SUV',7500,7500,960,1060,1560,true),
('AEROPUERTO_QRO','LA_VALISE','SUV',3200,3200,420,520,0,true),
('CIUDAD_CDMX','LA_VALISE','SUV',7500,7500,960,1060,0,true),
('CIUDAD_CELAYA','LA_VALISE','SUV',3200,3200,360,410,0,true),
('CIUDAD_GDL','LA_VALISE','SUV',9810,9810,1320,1420,2220,true),
('CIUDAD_LEON','LA_VALISE','SUV',2800,2800,540,590,0,true),
('CIUDAD_MORELIA','LA_VALISE','SUV',4800,4800,720,820,1320,true),
('CIUDAD_QRO','LA_VALISE','SUV',3200,3200,420,520,0,true),
('CIUDAD_SLP','LA_VALISE','SUV',NULL,NULL,600,700,1100,true),
('ESPERA_CADA_4_HRS','LA_VALISE','SUV',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','LA_VALISE','SUV',NULL,NULL,400,400,400,true),
('HORA_TOUR','LA_VALISE','SUV',935,935,180,0,0,true),
('HR_EXTRA_SERVICIO','LA_VALISE','SUV',935,935,144,174,0,true),
('LOCAL_SMA','LA_VALISE','SUV',935,935,180,230,0,true),
('SMA_HACIENDA','LA_VALISE','SUV',1870,1870,240,290,0,true),
('AEROPUERTO_BJX','LA_VALISE','MAXIVAN',4080,4080,420,520,0,true),
('AEROPUERTO_CDMX','LA_VALISE','MAXIVAN',8280,8280,960,1060,1560,true),
('AEROPUERTO_QRO','LA_VALISE','MAXIVAN',4080,4080,420,520,0,true),
('CIUDAD_CDMX','LA_VALISE','MAXIVAN',8280,8280,960,1060,0,true),
('CIUDAD_CELAYA','LA_VALISE','MAXIVAN',4080,4080,360,410,0,true),
('CIUDAD_GDL','LA_VALISE','MAXIVAN',10710,10710,1320,1420,2220,true),
('CIUDAD_LEON','LA_VALISE','MAXIVAN',4900,4900,540,590,0,true),
('CIUDAD_MORELIA','LA_VALISE','MAXIVAN',5600,5600,720,820,1320,true),
('CIUDAD_QRO','LA_VALISE','MAXIVAN',4080,4080,420,520,0,true),
('CIUDAD_SLP','LA_VALISE','MAXIVAN',NULL,NULL,600,700,1100,true),
('ESPERA_CADA_4_HRS','LA_VALISE','MAXIVAN',NULL,NULL,200,200,200,true),
('ESPERA_CON_PERNOCTACION','LA_VALISE','MAXIVAN',NULL,NULL,400,400,400,true),
('HORA_TOUR','LA_VALISE','MAXIVAN',1170,1170,180,0,0,true),
('HR_EXTRA_SERVICIO','LA_VALISE','MAXIVAN',1170,1170,144,174,0,true),
('LOCAL_SMA','LA_VALISE','MAXIVAN',1800,1800,180,230,0,true),
('SMA_HACIENDA','LA_VALISE','MAXIVAN',2200,2200,240,290,0,true),
('AEROPUERTO_BJX','CLIENTES_ESPECIALES','SEDAN',1500,1800,420,520,0,true),
('AEROPUERTO_BJX','CLIENTES_ESPECIALES','SEDAN',1600,1800,420,520,0,true),
('AEROPUERTO_BJX','CLIENTES_ESPECIALES','SEDAN',1800,1800,420,520,0,true),
('AEROPUERTO_BJX','CLIENTES_ESPECIALES','SEDAN',2000,1800,420,520,0,true),
('AEROPUERTO_BJX','CLIENTES_ESPECIALES','SEDAN',2100,1800,420,520,0,true),
('AEROPUERTO_CDMX','CLIENTES_ESPECIALES','SEDAN',5000,5000,960,1060,1560,true),
('AEROPUERTO_CDMX','CLIENTES_ESPECIALES','SEDAN',5500,5500,960,1060,1560,true),
('AEROPUERTO_QRO','CLIENTES_ESPECIALES','SEDAN',1500,1800,420,520,0,true),
('AEROPUERTO_QRO','CLIENTES_ESPECIALES','SEDAN',1600,1800,420,520,0,true),
('AEROPUERTO_QRO','CLIENTES_ESPECIALES','SEDAN',1800,1800,420,520,0,true),
('AEROPUERTO_QRO','CLIENTES_ESPECIALES','SEDAN',2000,1800,420,520,0,true),
('AEROPUERTO_QRO','CLIENTES_ESPECIALES','SEDAN',2100,1800,420,520,0,true)
) v(concept_code, tier_code, vehicle_code, price_day, price_night, pay_day, pay_night, pay_rt, active)
JOIN catalog_groups cg_concept ON cg_concept.code = 'PRICING_CONCEPT'
JOIN catalog_items concept ON concept.group_id = cg_concept.id AND concept.code = v.concept_code
JOIN catalog_groups cg_tier ON cg_tier.code = 'PRICING_CLIENT_TIER'
JOIN catalog_items tier ON tier.group_id = cg_tier.id AND tier.code = v.tier_code
JOIN catalog_groups cg_vehicle ON cg_vehicle.code = 'VEHICLE_TYPE'
JOIN catalog_items vehicle ON vehicle.group_id = cg_vehicle.id AND vehicle.code = v.vehicle_code
WHERE NOT EXISTS (
    SELECT 1 FROM pricing_rates pr
    WHERE pr.concept_id = concept.id
      AND pr.client_tier_id = tier.id
      AND pr.vehicle_type_id = vehicle.id
      AND pr.price_day IS NOT DISTINCT FROM v.price_day
      AND pr.price_night IS NOT DISTINCT FROM v.price_night
      AND pr.driver_pay_day IS NOT DISTINCT FROM v.pay_day
);


--------------------------------------------------------
-- 4) COLUMNAS NUEVAS EN accounts Y services
--------------------------------------------------------

ALTER TABLE accounts ADD COLUMN IF NOT EXISTS pricing_client_tier_id INTEGER REFERENCES catalog_items(id);

-- Toda cuenta que no tenga nivel de precio asignado (las que ya existían
-- antes de este cambio) queda como PUBLICO_GENERAL por default.
UPDATE accounts
   SET pricing_client_tier_id = atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
 WHERE pricing_client_tier_id IS NULL;

ALTER TABLE services ADD COLUMN IF NOT EXISTS pricing_concept_id INTEGER REFERENCES catalog_items(id);
ALTER TABLE services ADD COLUMN IF NOT EXISTS vehicle_type_id INTEGER REFERENCES catalog_items(id);
ALTER TABLE services ADD COLUMN IF NOT EXISTS quoted_price NUMERIC(10,2);
ALTER TABLE services ADD COLUMN IF NOT EXISTS quoted_driver_pay NUMERIC(10,2);


--------------------------------------------------------
-- 5) FUNCIÓN quote_service_price
--
-- Dado un servicio ya creado, más el concepto de precio (elegido por la
-- IA de extracción, ver nota abajo), el nivel de precio de la cuenta, la
-- unidad sugerida, y si aplica horario nocturno / viaje redondo, calcula
-- el precio y el pago a chofer, LOS GUARDA en la fila de services, y los
-- regresa para la alerta interna. Si no hay tarifa configurada para esa
-- combinación exacta, regresa NULL en vez de inventar un número -- el
-- staff decide el precio a mano en ese caso.
--------------------------------------------------------

CREATE OR REPLACE FUNCTION atlas.quote_service_price(
    p_service_id UUID,
    p_concept_code TEXT,
    p_client_tier_code TEXT,
    p_vehicle_type_code TEXT,
    p_is_night BOOLEAN,
    p_is_round_trip BOOLEAN
) RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    v_rate RECORD;
    v_price NUMERIC(10,2);
    v_driver_pay NUMERIC(10,2);
BEGIN
    SELECT pr.price_day, pr.price_night, pr.driver_pay_day, pr.driver_pay_night, pr.driver_pay_round_trip,
           pr.concept_id, pr.vehicle_type_id
      INTO v_rate
      FROM pricing_rates pr
      JOIN catalog_items concept ON concept.id = pr.concept_id
      JOIN catalog_items tier ON tier.id = pr.client_tier_id
      JOIN catalog_items vehicle ON vehicle.id = pr.vehicle_type_id
     WHERE concept.code = p_concept_code
       AND tier.code = p_client_tier_code
       AND vehicle.code = p_vehicle_type_code
       AND pr.active = true
     LIMIT 1;

    IF v_rate IS NULL THEN
        RETURN jsonb_build_object('found', false);
    END IF;

    v_price := CASE WHEN p_is_night THEN v_rate.price_night ELSE v_rate.price_day END;
    v_driver_pay := CASE
        WHEN p_is_round_trip AND v_rate.driver_pay_round_trip > 0 THEN v_rate.driver_pay_round_trip
        WHEN p_is_night THEN v_rate.driver_pay_night
        ELSE v_rate.driver_pay_day
    END;

    UPDATE services
       SET pricing_concept_id = v_rate.concept_id,
           vehicle_type_id = v_rate.vehicle_type_id,
           quoted_price = v_price,
           quoted_driver_pay = v_driver_pay
     WHERE id = p_service_id;

    RETURN jsonb_build_object(
        'found', true,
        'price', v_price,
        'driver_pay', v_driver_pay
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.quote_service_price(
    p_service_id UUID, p_concept_code TEXT, p_client_tier_code TEXT,
    p_vehicle_type_code TEXT, p_is_night BOOLEAN, p_is_round_trip BOOLEAN
) RETURNS jsonb
LANGUAGE sql
AS $function$
SELECT atlas.quote_service_price(p_service_id, p_concept_code, p_client_tier_code, p_vehicle_type_code, p_is_night, p_is_round_trip);
$function$;


--------------------------------------------------------
-- NOTA PARA CUANDO SE CABLEE EN n8n (siguiente paso, aún no hecho):
--
-- - pricing_concept_code: lo va a elegir la IA de extracción (ya normaliza
--   aeropuertos/ciudades), escogiendo de la lista fija de PRICING_CONCEPT.
-- - vehicle_type_code: se calcula en el flujo, no en Supabase --
--   SEDAN si passenger_count 1-3, SUV si 4-6, MAXIVAN si 7+ (v1, confirmado
--   con el usuario), con dos ajustes:
--     a) si el cliente pide explícitamente 4 pasajeros en SEDAN, se
--        respeta -- pero la respuesta al cliente menciona que se
--        recomienda SUV por comodidad (no se fuerza el cambio).
--     b) el equipaje puede forzar el salto a SUV aunque los pasajeros
--        quepan en SEDAN -- ej. 3 pasajeros con 3 maletas grandes cada
--        uno ya no caben. V1 solo necesita una regla razonable (pasajeros
--        + un umbral simple de equipaje); el usuario ya avisó que hay más
--        casos de este tipo que no conoce a detalle y que se resolverán
--        con una entrevista al personal de operación más adelante -- no
--        hay que tratar de cubrir cada escenario ahora.
-- - is_night: se calcula en el flujo a partir de scheduled_departure --
--   asumido "noche" fuera de 06:00-20:00 (ajustable).
-- - client_tier_code: se lee de accounts.pricing_client_tier_id de la
--   cuenta ya resuelta (Villa Santa Mónica / La Valise / JAQ / Publico
--   General) -- requiere que alguien marque manualmente las cuentas de
--   los 3 socios la primera vez (ver ejemplo abajo).
--
-- Ejemplo para marcar una cuenta existente como socio (correr a mano,
-- una vez identificado el account_id real del socio):
--
-- UPDATE accounts
--    SET pricing_client_tier_id = atlas.catalog('PRICING_CLIENT_TIER', 'LA_VALISE')
--  WHERE id = '<account_id-de-La-Valise>';
--------------------------------------------------------
