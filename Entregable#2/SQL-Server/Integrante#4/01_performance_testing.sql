/* ==========================================================================
   Entregable 2 — Pruebas de rendimiento — FASE "ANTES"

   CORRECCIÓN: SET STATISTICS IO/TIME ON es una configuración de SESIÓN,
   no "envuelve" un script completo de forma confiable si corres cada
   consulta por separado (seleccionando el texto y dando F5/Execute).
   Por eso aquí cada prueba trae su propio SET ON justo antes y su propio
   SET OFF justo después — así funciona igual si corres todo el script de
   una vez o si corres cada bloque de a uno.

   IMPORTANTE: para que el "Messages"/"Mensajes" muestre algo, tienes que
   correr el bloque COMPLETO que incluye el SET ON, la consulta, y el SET
   OFF, todo junto (selecciona las 3 partes y dale Execute una sola vez).
   Si seleccionas solo el SELECT sin el SET ON de ese mismo bloque, no vas
   a ver nada en Messages.
   ========================================================================== */

USE MobilityAnalysis;
GO

-- Opcional: limpiar caché antes de la primera corrida, para que "antes" y
-- "después" partan de las mismas condiciones. Solo en ambiente de prueba local.
DBCC FREEPROCCACHE;
DBCC DROPCLEANBUFFERS;
GO

-- ============================================================
-- PRUEBA 1: Atraso promedio por ruta
-- Selecciona TODO este bloque (desde SET hasta el segundo GO) y ejecútalo junto.
-- ============================================================
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT r.name,
       AVG(f.delay_min) AS avg_delay_min,
       COUNT(*) AS total_trips
FROM FACT_TRIP_HISTORY f
JOIN DIM_ROUTE r ON r.id_route = f.id_route
GROUP BY r.name
ORDER BY avg_delay_min DESC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================
-- PRUEBA 2: % de cumplimiento por unidad
-- ============================================================
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT v.plate,
       COUNT(*) AS total_trips,
       SUM(CASE WHEN f.on_time = 1 THEN 1 ELSE 0 END) AS on_time_trips,
       CAST(SUM(CASE WHEN f.on_time = 1 THEN 1 ELSE 0 END) AS DECIMAL(5,2))
           / COUNT(*) * 100 AS on_time_percentage
FROM FACT_TRIP_HISTORY f
JOIN DIM_UNIT v ON v.id_unit = f.id_unit
GROUP BY v.plate
ORDER BY on_time_percentage ASC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================
-- PRUEBA 3: filtro por rango de fechas (2026-S1)
-- ============================================================
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT d.year, d.month, AVG(f.delay_min) AS avg_delay_min
FROM FACT_TRIP_HISTORY f
JOIN DIM_DATE d ON d.id_date = f.id_date
WHERE f.id_date BETWEEN 20260101 AND 20260630
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================
-- PRUEBA 4: total de viajes por periodo
-- ============================================================
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    CASE
        WHEN f.id_date <= 20251231 THEN '2025'
        WHEN f.id_date <= 20260630 THEN '2026-S1'
        WHEN f.id_date <= 20261231 THEN '2026-S2'
        ELSE 'Otro'
    END AS periodo,
    COUNT(*) AS total_viajes
FROM FACT_TRIP_HISTORY f
GROUP BY
    CASE
        WHEN f.id_date <= 20251231 THEN '2025'
        WHEN f.id_date <= 20260630 THEN '2026-S1'
        WHEN f.id_date <= 20261231 THEN '2026-S2'
        ELSE 'Otro'
    END;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO