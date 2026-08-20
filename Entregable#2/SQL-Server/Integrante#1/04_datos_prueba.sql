/* Proyecto: Transporte Público
   Base de Datos: SQL-Server (DW)
   Semana 2: Datos de prueba */

USE MobilityAnalysis;
GO

IF NOT EXISTS (SELECT 1 FROM DIM_ROUTE)
BEGIN
    INSERT INTO DIM_ROUTE (name, origin, destination, distance_km)
    VALUES
        ('Route 1 - Centro', 'Terminal Central', 'Barrio Carmen', 8.5),
        ('Route 2 - Barranca', 'Terminal Central', 'Barranca', 14.5),
        ('Route 3 - Chacarita', 'Terminal Central', 'Chacarita', 6.2),
        ('Route 4 - El Roble', 'Terminal Central', 'El Roble', 11.0),
        ('Route 5 - Cocal', 'Terminal Central', 'Cocal', 17.8);
END
GO
 
IF NOT EXISTS (SELECT 1 FROM DIM_UNIT)
BEGIN
    INSERT INTO DIM_UNIT (plate, gps_id, capacity, year, status, unit_type)
    VALUES
        ('SJB-1001', 'GPS-001', 40, 2019, 'active', 'bus'),
        ('SJB-1002', 'GPS-002', 40, 2020, 'active', 'bus'),
        ('SJB-1003', 'GPS-003', 45, 2018, 'active', 'bus'),
        ('SJB-1004', 'GPS-004', 45, 2021, 'active', 'bus'),
        ('SJB-1005', 'GPS-005', 50, 2017, 'maintenance', 'bus'),
        ('SJB-1006', 'GPS-006', 38, 2022, 'active', 'bus'),
        ('SJB-1007', 'GPS-007', 40, 2019, 'active', 'bus'),
        ('SJB-1008', 'GPS-008', 42, 2020, 'active', 'bus');
END
GO
 
IF NOT EXISTS (SELECT 1 FROM DIM_DRIVER)
BEGIN
    INSERT INTO DIM_DRIVER (name, id_number, license)
    VALUES
        ('Juan Perez Mora', '1-1111-1111', 'B2-10001'),
        ('Maria Rojas Vindas', '1-1111-1112', 'B2-10002'),
        ('Carlos Solis Vargas', '1-1111-1113', 'B2-10003'),
        ('Ana Chaves Mendez', '1-1111-1114', 'B2-10004'),
        ('Luis Araya Duran', '1-1111-1115', 'B2-10005'),
        ('Sofia Jimenez Leon', '1-1111-1116', 'B2-10006'),
        ('Pedro Castro Nunez', '1-1111-1117', 'B2-10007'),
        ('Diana Fallas Ugalde', '1-1111-1118', 'B2-10008'),
        ('Marco Salas Cordero', '1-1111-1119', 'B2-10009'),
        ('Karen Brenes Ortiz', '1-1111-1120', 'B2-10010');
END
GO
 
IF NOT EXISTS (SELECT 1 FROM DIM_DATE)
BEGIN
    ;WITH Calendario AS (
        SELECT CAST('2025-01-01' AS DATE) AS fecha
        UNION ALL
        SELECT DATEADD(DAY, 1, fecha)
        FROM Calendario
        WHERE fecha < '2026-12-31'
    )
    INSERT INTO DIM_DATE (id_date, full_date, is_weekend, day_of_week, month, year)
    SELECT
        CAST(FORMAT(fecha, 'yyyyMMdd') AS INT),
        fecha,
        CASE WHEN DATENAME(WEEKDAY, fecha) IN ('Saturday','Sunday') THEN 1 ELSE 0 END,
        DATENAME(WEEKDAY, fecha),
        MONTH(fecha),
        YEAR(fecha)
    FROM Calendario
    OPTION (MAXRECURSION 800);
END
GO

-- PASO 0: limpiar posibles duplicados en DIM_ROUTE y DIM_DRIVER

;WITH RouteDedup AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY name ORDER BY id_route) AS rn
    FROM DIM_ROUTE
)
DELETE FROM RouteDedup WHERE rn > 1;

;WITH DriverDedup AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY id_number ORDER BY id_driver) AS rn
    FROM DIM_DRIVER
)
DELETE FROM DriverDedup WHERE rn > 1;
GO

TRUNCATE TABLE FACT_TRIP_HISTORY;
GO
--------------------------------
-- PASO 1: tabla temporal con 10,000 filas vacias

IF OBJECT_ID('tempdb..#Trips') IS NOT NULL DROP TABLE #Trips;

CREATE TABLE #Trips (
    rn          INT IDENTITY(1,1) PRIMARY KEY,
    id_date     INT NULL,
    id_route    INT NULL,
    id_unit     INT NULL,
    id_driver   INT NULL,
    delay_min   INT NULL,
    distancia   DECIMAL(6,2) NULL
);
GO

INSERT INTO #Trips (id_date)
SELECT TOP (10000) NULL
FROM sys.all_objects a
CROSS JOIN sys.all_objects b;
GO

-------------------------------
-- PASO 2: asignar valores aleatorios, forzando correlacion con t.rn en el ORDER BY para que se recalcule fila por fila

UPDATE t
SET t.id_date = d.id_date
FROM #Trips t
CROSS APPLY (
    SELECT TOP 1 id_date FROM DIM_DATE ORDER BY CHECKSUM(NEWID(), t.rn)
) d;
GO

UPDATE t
SET t.id_route = r.id_route
FROM #Trips t
CROSS APPLY (
    SELECT TOP 1 id_route FROM DIM_ROUTE ORDER BY CHECKSUM(NEWID(), t.rn)
) r;
GO

UPDATE t
SET t.id_unit = u.id_unit
FROM #Trips t
CROSS APPLY (
    SELECT TOP 1 id_unit FROM DIM_UNIT ORDER BY CHECKSUM(NEWID(), t.rn)
) u;
GO

UPDATE t
SET t.id_driver = c.id_driver
FROM #Trips t
CROSS APPLY (
    SELECT TOP 1 id_driver FROM DIM_DRIVER ORDER BY CHECKSUM(NEWID(), t.rn)
) c;
GO

UPDATE #Trips SET delay_min = (ABS(CHECKSUM(NEWID(), rn)) % 31) - 5;
UPDATE #Trips SET distancia = 5 + (ABS(CHECKSUM(NEWID(), rn)) % 15);
GO

-------------------------------------- 

-- Verificacion intermedia: si esto muestra variedad real de fechas y rutas, significa que se lleno correctamente.

SELECT TOP 10 * FROM #Trips;

SELECT
    COUNT(DISTINCT id_date)   AS fechas_distintas,
    COUNT(DISTINCT id_route)  AS rutas_distintas,
    COUNT(DISTINCT id_unit)   AS unidades_distintas,
    COUNT(DISTINCT id_driver) AS choferes_distintos
FROM #Trips;
GO
--------------------------------------

-- PASO 3: insertar en FACT_TRIP_HISTORY

INSERT INTO FACT_TRIP_HISTORY (
    id_trip_source, id_date, id_route, id_unit, id_driver,
    scheduled_departure, actual_departure,
    scheduled_arrival, actual_arrival,
    trip_duration_min, delay_min,
    distance_traveled_km, average_speed_kmh,
    on_time
)
SELECT
    rn,
    id_date,
    id_route,
    id_unit,
    id_driver,
    '07:00:00',
    DATEADD(MINUTE, delay_min, CAST('07:00:00' AS TIME)),
    DATEADD(MINUTE, 40, CAST('07:00:00' AS TIME)),
    DATEADD(MINUTE, 40 + delay_min, CAST('07:00:00' AS TIME)),
    40 + delay_min,
    delay_min,
    distancia,
    CAST(distancia / (40.0 / 60.0) AS DECIMAL(5,2)),
    CASE WHEN delay_min <= 5 THEN 1 ELSE 0 END
FROM #Trips;
GO
---------------------------

DROP TABLE #Trips;
GO

-----------------------------

-- Verificamos el total real de filas

SELECT COUNT(*) AS total_viajes FROM FACT_TRIP_HISTORY;

-----------------------------

-- Verificamos como quedaron distribuidas las filas por particion y filegroup

SELECT
    p.partition_number AS numero_particion,
    fg.name AS filegroup,
    p.rows AS total_filas
FROM sys.partitions p
JOIN sys.allocation_units au ON au.container_id = p.hobt_id AND au.type = 1
JOIN sys.filegroups fg ON fg.data_space_id = au.data_space_id
WHERE p.object_id = OBJECT_ID('FACT_TRIP_HISTORY')
  AND p.index_id IN (0, 1)
ORDER BY p.partition_number;