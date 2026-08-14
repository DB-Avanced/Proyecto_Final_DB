/* Proyecto: Transporte Público
   Base de Datos: SQL-Server 
   Analisis historico de movilidad  
   CRUD del Data Warehouse */
   
USE MobilityAnalysis;
GO
----------------------------------------------------

/* Tabla DIM_DATE */

-- Insertar una fecha nueva en el calendario
INSERT INTO DIM_DATE (id_date, full_date, is_weekend, day_of_week, month, year)
VALUES (20260805, '2026-08-05', 0, 'Wednesday', 8, 2026);

-- Consultar por fecha especifica
SELECT * FROM DIM_DATE WHERE full_date = '2026-08-05';

-- UPDATE (marcar una fecha como fin de semana)
UPDATE DIM_DATE
SET is_weekend = 1
WHERE id_date = 20260805;
GO

----------------------------------------------------

/* Tabla DIM_ROUTE */

-- Insertar una ruta nueva
INSERT INTO DIM_ROUTE (name, origin, destination, distance_km)
VALUES ('Route 12 - Downtown Puntarenas', 'Central Terminal', 'Barranca', 14.5);

-- Consultar todas las rutas
SELECT * FROM DIM_ROUTE;

-- Consultar una ruta especifica
SELECT * FROM DIM_ROUTE WHERE name = 'Route 12 - Downtown Puntarenas';

-- Actualizar distancia de una ruta
UPDATE DIM_ROUTE
SET distance_km = 15.0
WHERE id_route = 1;
GO

----------------------------------------------------

/* Tabla DIM_UNIT */

-- Insertar una unidad nueva
INSERT INTO DIM_UNIT (plate, gps_id, capacity, year, status, unit_type)
VALUES ('SJB-1234', 'GPS-045', 40, 2019, 'active', 'bus');

-- Consultar todas las unidades
SELECT * FROM DIM_UNIT;

-- Consultar unidades por tipo
SELECT * FROM DIM_UNIT WHERE unit_type = 'bus';

-- Consultar unidad por GPS ID
SELECT * FROM DIM_UNIT WHERE gps_id = 'GPS-045';

-- Cambiar estado operativo de una unidad
UPDATE DIM_UNIT
SET status = 'maintenance'
WHERE id_unit = 1;
GO

----------------------------------------------------

/* Tabla DIM_DRIVER */

-- Insertar un chofer nuevo
INSERT INTO DIM_DRIVER (name, id_number, license)
VALUES ('Juan Perez Mora', '1-1234-5678', 'B2-45678');

-- Consultar todos los choferes
SELECT * FROM DIM_DRIVER;

-- Consultar chofer por numero de cedula
SELECT * FROM DIM_DRIVER WHERE id_number = '1-1234-5678';

-- Actualizar numero de licencia
UPDATE DIM_DRIVER
SET license = 'B2-99999'
WHERE id_driver = 1;
GO

----------------------------------------------------

/* Tabla FACT_TRIP_HISTORY */

-- Insertar un viaje ya procesado por el ETL
INSERT INTO FACT_TRIP_HISTORY (
    id_trip_source, id_date, id_route, id_unit, id_driver,
    scheduled_departure, actual_departure,
    scheduled_arrival, actual_arrival,
    trip_duration_min, delay_min,
    distance_traveled_km, average_speed_kmh,
    on_time
)
VALUES (
    501, 20260805, 1, 1, 1,
    '07:00:00', '07:08:00',
    '07:40:00', '07:52:00',
    44, 8,
    14.8, 20.2,
    0
);

-- Consultar todos los viajes historicos
SELECT * FROM FACT_TRIP_HISTORY;

-- READ con join a las dimensiones
-- (RF-10: historial de recorridos, RF-13: indicadores de desempeno)
SELECT
    f.id_trip_fact,
    d.full_date,
    r.name          AS route,
    v.plate         AS unit,
    dr.name         AS driver,
    f.delay_min,
    f.on_time
FROM FACT_TRIP_HISTORY f
JOIN DIM_DATE    d  ON d.id_date    = f.id_date
JOIN DIM_ROUTE   r  ON r.id_route   = f.id_route
JOIN DIM_UNIT    v  ON v.id_unit    = f.id_unit
JOIN DIM_DRIVER  dr ON dr.id_driver = f.id_driver;

-- Corregir un atraso mal calculado
UPDATE FACT_TRIP_HISTORY
SET delay_min = 10,
    on_time = 0
WHERE id_trip_fact = 1;
GO

----------------------------------------------------

/* DELETE - se ejecutan al final y en orden inverso a las
   dependencias, primero el fact, despues las dimensiones,,
   para no llegar a violar las llaves foraneas */

DELETE FROM FACT_TRIP_HISTORY
WHERE id_trip_fact = 1;

DELETE FROM DIM_DRIVER
WHERE id_driver = 1;

DELETE FROM DIM_UNIT
WHERE id_unit = 1;

DELETE FROM DIM_ROUTE
WHERE id_route = 1;

DELETE FROM DIM_DATE
WHERE id_date = 20260805;
GO