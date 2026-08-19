USE MobilityAnalysis;
GO

-- 1. Cantidad de datos cargados
SELECT 'DIM_ROUTE' AS tabla, COUNT(*) AS cantidad FROM DIM_ROUTE
UNION ALL
SELECT 'DIM_DRIVER', COUNT(*) FROM DIM_DRIVER
UNION ALL
SELECT 'DIM_UNIT', COUNT(*) FROM DIM_UNIT
UNION ALL
SELECT 'DIM_DATE', COUNT(*) FROM DIM_DATE
UNION ALL
SELECT 'FACT_TRIP_HISTORY', COUNT(*) FROM FACT_TRIP_HISTORY
UNION ALL
SELECT 'FACT_GPS_EVENT', COUNT(*) FROM FACT_GPS_EVENT;
GO

-- 2. Viajes cargados
SELECT
    f.id_trip_source,
    r.name AS ruta,
    u.plate AS unidad,
    d.name AS conductor,
    f.delay_min AS atraso_minutos,
    f.on_time AS puntual
FROM FACT_TRIP_HISTORY f
JOIN DIM_ROUTE r ON r.id_route = f.id_route
JOIN DIM_UNIT u ON u.id_unit = f.id_unit
JOIN DIM_DRIVER d ON d.id_driver = f.id_driver
ORDER BY f.id_trip_source;
GO

-- 3. Eventos de MongoDB cargados
SELECT
    u.plate AS unidad,
    g.event_timestamp,
    g.speed,
    g.fuel,
    g.engine_temperature
FROM FACT_GPS_EVENT g
JOIN DIM_UNIT u ON u.id_unit = g.id_unit
ORDER BY g.event_timestamp;
GO
