/* Proyecto: Transporte Público
   Base de Datos: SQL-Server (DW)
   Semana 2: Filegroups para particionamiento de FACT_TRIP_HISTORY */

-- Filegroups 

ALTER DATABASE MobilityAnalysis ADD FILEGROUP FG_TRIP_2025;
ALTER DATABASE MobilityAnalysis ADD FILEGROUP FG_TRIP_2026_S1;
ALTER DATABASE MobilityAnalysis ADD FILEGROUP FG_TRIP_2026_S2;
ALTER DATABASE MobilityAnalysis ADD FILEGROUP FG_TRIP;
GO

----------------------------------------------------

-- Creacion de los archivos fisicos para cada filegroup

ALTER DATABASE MobilityAnalysis ADD FILE (
    NAME = 'Trip_2025',
    FILENAME = '/var/opt/mssql/data/Trip_2025.ndf'
) TO FILEGROUP FG_TRIP_2025;
GO

ALTER DATABASE MobilityAnalysis ADD FILE (
    NAME = 'Trip_2026_S1',
    FILENAME = '/var/opt/mssql/data/Trip_2026_S1.ndf'
) TO FILEGROUP FG_TRIP_2026_S1;
GO

ALTER DATABASE MobilityAnalysis ADD FILE (
    NAME = 'Trip_2026_S2',
    FILENAME = '/var/opt/mssql/data/Trip_2026_S2.ndf'
) TO FILEGROUP FG_TRIP_2026_S2;
GO

ALTER DATABASE MobilityAnalysis ADD FILE (
    NAME = 'Trip',
    FILENAME = '/var/opt/mssql/data/Trip.ndf'
) TO FILEGROUP FG_TRIP;
GO

----------------------------------------------------

-- Verificamos que se crearon correctamente:

SELECT name, type_desc, is_default
FROM sys.filegroups;