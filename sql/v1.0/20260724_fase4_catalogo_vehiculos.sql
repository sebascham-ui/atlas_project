-- =====================================================
-- FASE 4 -- Catálogo real de vehículos (20 unidades)
-- Atlas Project -- 2026-07-24
--
-- Contexto: la tabla `vehicle_types` es una tabla DEDICADA (uuid,
-- passenger_capacity, luggage_capacity) y es la que de verdad
-- referencia `vehicles.vehicle_type_id`. Es DISTINTA del grupo
-- `VEHICLE_TYPE` de catalog_items que crea pricing_engine_v1.sql
-- (ese es solo para las tarifas -- SEDAN/SUV/MAXIVAN, 3 códigos).
-- No se toca esa tabla de precios en esta migración.
--
-- También se descubrió que `vehicles.status_id` SÍ usa el patrón
-- genérico catalog_groups/catalog_items (como todas las demás
-- tablas del sistema), y ese grupo (VEHICLE_STATUS) nunca se había
-- sembrado -- sin esto, cualquier INSERT en vehicles fallaría.
-- =====================================================

-- ---------------------------------------------------
-- 1) vehicle_types -- los 5 niveles oficiales de la empresa
--    (fuente: página web oficial de la empresa, no la hoja
--    "Tipos de Unidad" del Excel, que traía números aproximados)
-- ---------------------------------------------------
INSERT INTO vehicle_types(name, passenger_capacity, luggage_capacity, description)
SELECT v.name, v.passenger_capacity, v.luggage_capacity, v.description
FROM (VALUES
    ('SEDAN',       3, 4,  'Ej. Toyota Camry. Hasta 3 pasajeros + 4 maletas.'),
    ('CROSSOVER',   3, 5,  'Ej. Tucson, RAV4. Hasta 3 pasajeros + 5 maletas.'),
    ('SUV MEDIUM',  4, 7,  'Ej. Palisade, Sienna. Hasta 4 pasajeros + 7 maletas.'),
    ('SUV FULL',    5, 12, 'Ej. Suburban. Hasta 5 pasajeros + 12 maletas.'),
    ('MAXIVAN',     9, 15, 'Ej. Hiace. Hasta 9 pasajeros + 15 maletas.')
) v(name, passenger_capacity, luggage_capacity, description)
WHERE NOT EXISTS (SELECT 1 FROM vehicle_types t WHERE t.name = v.name);

-- ---------------------------------------------------
-- 2) VEHICLE_STATUS -- catálogo genérico que faltaba
--    (mismo patrón ACTIVE/INACTIVE que ya usa PERSON_STATUS)
-- ---------------------------------------------------
INSERT INTO catalog_groups(code, name)
SELECT 'VEHICLE_STATUS', 'Estado del Vehículo'
WHERE NOT EXISTS (SELECT 1 FROM catalog_groups WHERE code = 'VEHICLE_STATUS');

INSERT INTO catalog_items(group_id, code, label, sort_order)
SELECT g.id, v.code, v.label, v.sort_order
FROM catalog_groups g
CROSS JOIN (VALUES
    ('ACTIVE', 'Activo', 1),
    ('INACTIVE', 'Inactivo', 2)
) v(code, label, sort_order)
WHERE g.code = 'VEHICLE_STATUS'
AND NOT EXISTS (SELECT 1 FROM catalog_items i WHERE i.group_id = g.id AND i.code = v.code);

-- ---------------------------------------------------
-- 3) Las 20 unidades reales (catalogo_unidades_TyTSMM.xlsx)
--
-- Notas:
--  - El VIN se deja en NULL por ahora. Para las unidades con GPS
--    de MyGeotab lo podemos rellenar después con un UPDATE aparte
--    (ya lo tenemos de la API, falta cruzarlo aquí).
--  - "FRONTERIZO / JEEP" del Excel se capturó como Nissan Frontier
--    -- confírmame si el año/placa no corresponden a esa unidad.
--  - Los códigos U-01...U-20 quedan agrupados por tipo (sedanes,
--    luego crossovers, etc.) solo para que sea fácil leerlos --
--    el tipo real siempre se calcula desde vehicle_type_id, el
--    código no lleva ninguna lógica escondida.
--  - El código interno (U-01, U-02...) es ahora el identificador
--    único de cada unidad. Las letras B/N/A que traían los Camry
--    y Suburban en el Excel ya no hacen falta -- color y placa
--    quedan como columnas propias.
-- ---------------------------------------------------
INSERT INTO vehicles(internal_code, vehicle_type_id, brand, model, model_year, color, license_plate, vin, status_id, allows_pets, notes)
SELECT
    v.internal_code,
    t.id,
    v.brand,
    v.model,
    v.model_year,
    v.color,
    v.license_plate,
    NULL,
    atlas.catalog('VEHICLE_STATUS', 'ACTIVE'),
    true,
    CASE WHEN v.internal_code = 'U-12' THEN 'Excel original decía marca "FRONTERIZO" / modelo "JEEP" -- se capturó como Nissan Frontier, confirmar con el dueño.' END
FROM (VALUES
    -- SEDAN
    ('U-01', 'SEDAN',      'Toyota',   'Camry',    2012, 'Plata',       '669RM9'),
    ('U-02', 'SEDAN',      'Toyota',   'Camry',    2012, 'Plata',       '805RM9'),
    ('U-03', 'SEDAN',      'Toyota',   'Camry',    2018, 'Plata',       '08RB3H'),
    ('U-04', 'SEDAN',      'Toyota',   'Camry',    2025, 'Blanco',      '11RD8A'),
    ('U-05', 'SEDAN',      'Honda',    'Fit',      2017, 'Blanco',      'GNP404F'),
    ('U-06', 'SEDAN',      'Toyota',   'Corolla',  2016, 'Blanco',      'GVG1853'),
    -- CROSSOVER
    ('U-07', 'CROSSOVER',  'Hyundai',  'Tucson',   2024, 'Blanco',      'GJM442F'),
    ('U-08', 'CROSSOVER',  'Honda',    'HRV',      2026, 'Gris',        'UKK642L'),
    ('U-09', 'CROSSOVER',  'Nissan',   'Xtrail',   2016, 'Blanco',      'GPV312D'),
    ('U-10', 'CROSSOVER',  'Toyota',   'RAV4',     2019, 'Verde',       'GMP975C'),
    ('U-11', 'CROSSOVER',  'Mazda',    NULL,       2017, 'Rojo',        'GMP976C'),
    ('U-12', 'CROSSOVER',  'Nissan',   'Frontier', 2013, 'Rojo',        'PJL669E'),
    -- SUV MEDIUM
    ('U-13', 'SUV MEDIUM', 'Toyota',   'Sienna',   2022, 'Vino',        '90RD8D'),
    ('U-14', 'SUV MEDIUM', 'Hyundai',  'Palisade', 2024, 'Negro',       'PVD962E'),
    -- SUV FULL
    ('U-15', 'SUV FULL',   'Chevrolet','Suburban', 2016, 'Plata',       '07RB3H'),
    ('U-16', 'SUV FULL',   'Chevrolet','Suburban', 2019, 'Blanco',      '96RE7K'),
    ('U-17', 'SUV FULL',   'Chevrolet','Suburban', 2021, 'Blanco',      '81RE1L'),
    -- MAXIVAN
    ('U-18', 'MAXIVAN',    'Toyota',   'Hiace',    2011, 'Azul marino', '794RM9'),
    ('U-19', 'MAXIVAN',    'Toyota',   'Hiace',    2021, 'Blanco',      '90RC7M'),
    ('U-20', 'MAXIVAN',    'Toyota',   'Hiace',    2018, 'Blanco',      '61RA8X')
) v(internal_code, type_name, brand, model, model_year, color, license_plate)
LEFT JOIN vehicle_types t ON t.name = v.type_name
WHERE NOT EXISTS (SELECT 1 FROM vehicles ve WHERE ve.internal_code = v.internal_code);
