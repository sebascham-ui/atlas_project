-- =====================================================
-- FASE 5 -- VIN de las unidades con GPS (MyGeotab)
-- Atlas Project -- 2026-07-24
--
-- Cruce por año/modelo entre los 11 dispositivos reales que
-- devuelve MyGeotab (workflow "ATLAS - Prueba de conexión
-- MyGeotab", ejecución 290) y las 20 unidades ya cargadas en
-- Fase 4. Solo actualiza el VIN -- no toca ninguna otra columna.
--
-- Protegido con "WHERE vin IS NULL" para no pisar un VIN que ya
-- hayas capturado a mano mientras tanto.
--
-- Un solo dispositivo (HIACE B / HIACE BLANCA, U-20) no tiene VIN
-- cargado en MyGeotab todavía -- por eso no aparece aquí. Ya se
-- confirmó que esa unidad sí trae GPS, solo falta el VIN cuando
-- MyGeotab lo tenga.
-- =====================================================

UPDATE vehicles SET vin = '4T1BF1FK1CU035855' WHERE internal_code = 'U-02' AND vin IS NULL; -- CAMRY B, 2012
UPDATE vehicles SET vin = '4T1B11HK0JU503132' WHERE internal_code = 'U-03' AND vin IS NULL; -- CAMRY N, 2018
UPDATE vehicles SET vin = '4T1DAACK6SU056873' WHERE internal_code = 'U-04' AND vin IS NULL; -- CAMRY BLANCO, 2025
UPDATE vehicles SET vin = '3HGRZ1852TM008056' WHERE internal_code = 'U-08' AND vin IS NULL; -- HONDA HRV, 2026
UPDATE vehicles SET vin = 'TMCJB3UE1RJ360841' WHERE internal_code = 'U-07' AND vin IS NULL; -- TUCSON
UPDATE vehicles SET vin = '5TDGRKEC0NS116192' WHERE internal_code = 'U-13' AND vin IS NULL; -- SIENNA, 2022
UPDATE vehicles SET vin = 'KM8R64GE4RU684602' WHERE internal_code = 'U-14' AND vin IS NULL; -- PALISADE, 2024
UPDATE vehicles SET vin = '1GNSC8KC0KR290350' WHERE internal_code = 'U-16' AND vin IS NULL; -- SUBURBAN BLANCA, 2019
UPDATE vehicles SET vin = '1GNSC9KD0MR172297' WHERE internal_code = 'U-17' AND vin IS NULL; -- SUBURBAN N, 2021
UPDATE vehicles SET vin = 'JTFJM9CP7M6003591' WHERE internal_code = 'U-19' AND vin IS NULL; -- HIACE NUEVA, 2021
