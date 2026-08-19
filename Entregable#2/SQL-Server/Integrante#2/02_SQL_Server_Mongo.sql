USE MobilityAnalysis;
GO

-- Esta tabla recibe los eventos de GPS de MongoDB.
CREATE TABLE FACT_GPS_EVENT (
    id_gps_event BIGINT IDENTITY(1,1) PRIMARY KEY,
    source_id VARCHAR(50) NOT NULL UNIQUE,
    id_date INT NOT NULL,
    id_unit INT NOT NULL,
    event_timestamp DATETIME2 NOT NULL,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    speed DECIMAL(8,2),
    direction DECIMAL(8,2),
    engine VARCHAR(10),
    engine_temperature DECIMAL(8,2),
    fuel DECIMAL(8,2)
);
GO

-- Comprobación rápida
SELECT TOP 10 *
FROM FACT_GPS_EVENT;
GO
