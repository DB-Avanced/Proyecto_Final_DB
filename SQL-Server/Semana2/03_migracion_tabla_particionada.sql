/* Proyecto: Transporte Público
   Base de Datos: SQL-Server (DW)
   Semana 3: Migracion de FACT_TRIP_HISTORY a tabla particionada */

-- PASO 0: Renombrar la tabla actual para no perder los datos

EXEC sp_rename 'FACT_TRIP_HISTORY', 'FACT_TRIP_HISTORY_OLD';
GO

-- PASO 1: Eliminar las constraints de la tabla vieja 

ALTER TABLE FACT_TRIP_HISTORY_OLD DROP CONSTRAINT PK_FACT_TRIP_HISTORY;
ALTER TABLE FACT_TRIP_HISTORY_OLD DROP CONSTRAINT UQ_FACT_TRIP_SOURCE;
ALTER TABLE FACT_TRIP_HISTORY_OLD DROP CONSTRAINT FK_FACT_DATE;
ALTER TABLE FACT_TRIP_HISTORY_OLD DROP CONSTRAINT FK_FACT_ROUTE;
ALTER TABLE FACT_TRIP_HISTORY_OLD DROP CONSTRAINT FK_FACT_UNIT;
ALTER TABLE FACT_TRIP_HISTORY_OLD DROP CONSTRAINT FK_FACT_DRIVER;
GO

-- PASO 2: Crear la nueva tabla, particionada por id_date,
-- usando el esquema de particion ya definido

CREATE TABLE FACT_TRIP_HISTORY (
    id_trip_fact            BIGINT          IDENTITY(1,1) NOT NULL,
    id_trip_source          INT             NOT NULL,
    id_date                 INT             NOT NULL,
    id_route                INT             NOT NULL,
    id_unit                 INT             NOT NULL,
    id_driver               INT             NOT NULL,
    scheduled_departure     TIME            NOT NULL,
    actual_departure        TIME            NOT NULL,
    scheduled_arrival       TIME            NOT NULL,
    actual_arrival          TIME            NOT NULL,
    trip_duration_min       INT             NOT NULL,
    delay_min               INT             NOT NULL,
    distance_traveled_km    DECIMAL(6,2)    NOT NULL,
    average_speed_kmh       DECIMAL(5,2)    NOT NULL,
    on_time                 BIT             NOT NULL,
    CONSTRAINT PK_FACT_TRIP_HISTORY PRIMARY KEY (id_trip_fact, id_date),
    CONSTRAINT UQ_FACT_TRIP_SOURCE UNIQUE (id_trip_source, id_date),
    CONSTRAINT FK_FACT_DATE    FOREIGN KEY (id_date)    REFERENCES DIM_DATE(id_date),
    CONSTRAINT FK_FACT_ROUTE   FOREIGN KEY (id_route)   REFERENCES DIM_ROUTE(id_route),
    CONSTRAINT FK_FACT_UNIT    FOREIGN KEY (id_unit)    REFERENCES DIM_UNIT(id_unit),
    CONSTRAINT FK_FACT_DRIVER  FOREIGN KEY (id_driver)  REFERENCES DIM_DRIVER(id_driver)
) ON PS_TripByPeriod(id_date);
GO

-- PASO 3: Copiar los datos que ya existieran en la tabla vieja
-- (si esta vacia, este INSERT simplemente no copia nada, sin error)

SET IDENTITY_INSERT FACT_TRIP_HISTORY ON;

INSERT INTO FACT_TRIP_HISTORY (
    id_trip_fact, id_trip_source, id_date, id_route, id_unit, id_driver,
    scheduled_departure, actual_departure, scheduled_arrival, actual_arrival,
    trip_duration_min, delay_min, distance_traveled_km, average_speed_kmh, on_time
)
SELECT
    id_trip_fact, id_trip_source, id_date, id_route, id_unit, id_driver,
    scheduled_departure, actual_departure, scheduled_arrival, actual_arrival,
    trip_duration_min, delay_min, distance_traveled_km, average_speed_kmh, on_time
FROM FACT_TRIP_HISTORY_OLD;

SET IDENTITY_INSERT FACT_TRIP_HISTORY OFF;
GO

-- PASO 4: Eliminar la tabla vieja, ya migrada
DROP TABLE FACT_TRIP_HISTORY_OLD;
GO

-- Verificar que la tabla quedo particionada correctamente
SELECT
    $PARTITION.PF_TripByPeriod(id_date) AS numero_particion,
    fg.name AS filegroup,
    COUNT(*) AS total_filas
FROM FACT_TRIP_HISTORY f
JOIN sys.partitions p ON p.object_id = OBJECT_ID('FACT_TRIP_HISTORY')
JOIN sys.allocation_units au ON au.container_id = p.partition_id
JOIN sys.filegroups fg ON fg.data_space_id = au.data_space_id
GROUP BY $PARTITION.PF_TripByPeriod(id_date), fg.name
ORDER BY numero_particion;