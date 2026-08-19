/* Proyecto: Transporte Público
   Base de Datos: SQL-Server (DW)
   Semana 2: Funcion y esquema de particion para FACT_TRIP_HISTORY */

----------------------------------------------------

-- FUNCION DE PARTICION

CREATE PARTITION FUNCTION PF_TripByPeriod (INT)
AS RANGE LEFT FOR VALUES (
    20251231,   -- limite del periodo 2025 (hasta 31/dic/2025)
    20260630,   -- limite del periodo 2026-S1 (hasta 30/jun/2026)
    20261231    -- limite del periodo 2026-S2 (hasta 31/dic/2026)
);
GO

----------------------------------------------------

-- ESQUEMA DE PARTICION

CREATE PARTITION SCHEME PS_TripByPeriod
AS PARTITION PF_TripByPeriod
TO (FG_TRIP_2025, FG_TRIP_2026_S1, FG_TRIP_2026_S2, FG_TRIP);
GO

----------------------------------------------------

-- Verificamos que se crearon correctamente:

SELECT * FROM sys.partition_functions;
SELECT * FROM sys.partition_schemes;