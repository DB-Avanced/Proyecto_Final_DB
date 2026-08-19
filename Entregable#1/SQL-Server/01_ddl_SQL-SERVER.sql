
/* Proyecto: Transporte Público
   Base de Datos: SQL-Server (DW)
   Analisis historico de movilidad  */
  

CREATE DATABASE MobilityAnalysis;
GO

USE MobilityAnalysis;
GO

/* Tabla DIM_DATE */

CREATE TABLE DIM_DATE (
    id_date         INT             NOT NULL,
    full_date       DATE            NOT NULL,
    is_weekend      BIT             NOT NULL DEFAULT 0,
    day_of_week     VARCHAR(15)     NOT NULL,
    month           TINYINT         NOT NULL,
    year            SMALLINT        NOT NULL,
    CONSTRAINT PK_DIM_DATE PRIMARY KEY (id_date)
);
GO

/* Tabla DIM_ROUTE - Copia simplificada de "routes" de PostgreSQL */

CREATE TABLE DIM_ROUTE (
    id_route        INT             IDENTITY(1,1) NOT NULL,
    name            VARCHAR(100)    NOT NULL,
    origin          VARCHAR(100)    NOT NULL,
    destination     VARCHAR(100)    NOT NULL,
    distance_km     DECIMAL(6,2)    NOT NULL,
    CONSTRAINT PK_DIM_ROUTE PRIMARY KEY (id_route)
);
GO

/*  Tabla DIM_UNIT - Copia simplificada de "units" + tipo de la jerarquia MOR */

CREATE TABLE DIM_UNIT (
    id_unit      INT             IDENTITY(1,1) NOT NULL,
    plate           VARCHAR(15)     NOT NULL,
    gps_id          VARCHAR(50)     NOT NULL,
    capacity        SMALLINT        NOT NULL,
    year            SMALLINT        NULL,
    status          VARCHAR(20)     NOT NULL,
    unit_type    VARCHAR(20)     NOT NULL,   -- bus, train, metro
    CONSTRAINT PK_DIM_UNIT PRIMARY KEY (id_unit),
    CONSTRAINT UQ_DIM_UNIT_GPS UNIQUE (gps_id)
);
GO

/* Tabla  DIM_DRIVER - Copia simplificada de "drivers" de PostgreSQL  */

CREATE TABLE DIM_DRIVER (
    id_driver       INT             IDENTITY(1,1) NOT NULL,
    name            VARCHAR(100)    NOT NULL,
    id_number       VARCHAR(20)     NOT NULL,
    license         VARCHAR(20)     NOT NULL,
    CONSTRAINT PK_DIM_DRIVER PRIMARY KEY (id_driver)
);
GO

/* Tabla FACT_TRIP_HISTORY
   Grano: un registro por viaje realizado
   id_trip_source = id de "trips" en PostgreSQL, para
   trazabilidad hacia el sistema transaccional */

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
    delay_min               INT             NOT NULL,   -- negativo si llego antes
    distance_traveled_km    DECIMAL(6,2)    NOT NULL,
    average_speed_kmh       DECIMAL(5,2)    NOT NULL,
    on_time                 BIT             NOT NULL,
    CONSTRAINT PK_FACT_TRIP_HISTORY PRIMARY KEY (id_trip_fact),
    CONSTRAINT UQ_FACT_TRIP_SOURCE UNIQUE (id_trip_source),
    CONSTRAINT FK_FACT_DATE    FOREIGN KEY (id_date)    REFERENCES DIM_DATE(id_date),
    CONSTRAINT FK_FACT_ROUTE   FOREIGN KEY (id_route)   REFERENCES DIM_ROUTE(id_route),
    CONSTRAINT FK_FACT_UNIT FOREIGN KEY (id_unit) REFERENCES DIM_UNIT(id_unit),
    CONSTRAINT FK_FACT_DRIVER  FOREIGN KEY (id_driver)  REFERENCES DIM_DRIVER(id_driver)
);
GO

----------------------------------------------------

/* Indices de apoyo para consultas de analisis */

CREATE INDEX IX_FACT_ROUTE_DATE ON FACT_TRIP_HISTORY (id_route, id_date);
CREATE INDEX IX_FACT_UNIT ON FACT_TRIP_HISTORY (id_unit);
CREATE INDEX IX_FACT_DRIVER ON FACT_TRIP_HISTORY (id_driver);
GO

/* Consultas de analisis*/

-- Atraso promedio por ruta
SELECT r.name,
       AVG(f.delay_min) AS avg_delay_min,
       COUNT(*) AS total_trips
FROM FACT_TRIP_HISTORY f
JOIN DIM_ROUTE r ON r.id_route = f.id_route
GROUP BY r.name
ORDER BY avg_delay_min DESC;

-- Porcentaje de cumplimiento de horario por unidad
SELECT v.plate,
       COUNT(*) AS total_trips,
       SUM(CASE WHEN f.on_time = 1 THEN 1 ELSE 0 END) AS on_time_trips,
       CAST(SUM(CASE WHEN f.on_time = 1 THEN 1 ELSE 0 END) AS DECIMAL(5,2))
           / COUNT(*) * 100 AS on_time_percentage
FROM FACT_TRIP_HISTORY f
JOIN DIM_UNIT v ON v.id_unit = f.id_unit
GROUP BY v.plate
ORDER BY on_time_percentage ASC;

-- Tendencia de atrasos por mes
SELECT d.year, d.month, AVG(f.delay_min) AS avg_delay_min
FROM FACT_TRIP_HISTORY f
JOIN DIM_DATE d ON d.id_date = f.id_date
GROUP BY d.year, d.month
ORDER BY d.year, d.month;