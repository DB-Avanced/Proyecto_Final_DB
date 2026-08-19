/* Proyecto: Transporte Público
   Base de Datos: SQL-Server (DW)
   Semana 2: Indices sobre FACT_TRIP_HISTORY, la tabla particionada */

USE MobilityAnalysis;
GO

-- Indice para la consulta de atraso promedio por ruta
-- (incluye delay_min para que la consulta se resuelva
-- leyendo solo el indice, sin tener que ir a la tabla completa)
CREATE NONCLUSTERED INDEX IX_FACT_ROUTE
ON FACT_TRIP_HISTORY (id_route)
INCLUDE (delay_min)
ON PS_TripByPeriod(id_date);
GO

-- Indice para consultas de cumplimiento por unidad
CREATE NONCLUSTERED INDEX IX_FACT_UNIT
ON FACT_TRIP_HISTORY (id_unit)
INCLUDE (on_time)
ON PS_TripByPeriod(id_date);
GO

-- Indice para consultas por chofer
CREATE NONCLUSTERED INDEX IX_FACT_DRIVER
ON FACT_TRIP_HISTORY (id_driver)
ON PS_TripByPeriod(id_date);
GO

-- Verificar que los indices se crearon y quedaron particionados
SELECT
    i.name AS indice,
    i.type_desc AS tipo,
    p.partition_number,
    fg.name AS filegroup,
    p.rows AS filas_en_esta_particion
FROM sys.indexes i
JOIN sys.partitions p ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.allocation_units au ON au.container_id = p.hobt_id AND au.type = 1
JOIN sys.filegroups fg ON fg.data_space_id = au.data_space_id
WHERE i.object_id = OBJECT_ID('FACT_TRIP_HISTORY')
  AND i.name IS NOT NULL
ORDER BY i.name, p.partition_number;