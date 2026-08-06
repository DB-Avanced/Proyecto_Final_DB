-- ============================================================================
-- CRUD - Escenario 3: Transporte Público Inteligente
-- Motor: PostgreSQL
-- Convención: los placeholders $1, $2, ... se reemplazan con los valores reales
--             al ejecutar (via psql \bind, driver de la app, etc.). También se
--             deja un ejemplo con valores literales debajo de cada bloque.
-- ============================================================================


-- ============================================================================
-- 1. ROUTES
-- ============================================================================

-- CREATE
INSERT INTO routes (name, origin, destination, distance_km)
VALUES ($1, $2, $3, $4)
RETURNING id;
-- Ejemplo:
-- INSERT INTO routes (name, origin, destination, distance_km)
-- VALUES ('Ruta 1 - Centro', 'Terminal Norte', 'Terminal Sur', 12.5)
-- RETURNING id;

-- READ (todas)
SELECT id, name, origin, destination, distance_km FROM routes ORDER BY id;

-- READ (por id)
SELECT id, name, origin, destination, distance_km FROM routes WHERE id = $1;

-- UPDATE
UPDATE routes
SET name = $1, origin = $2, destination = $3, distance_km = $4
WHERE id = $5;

-- DELETE
DELETE FROM routes WHERE id = $1;
-- Nota: fallará con error de FK si la ruta tiene schedules, route_stops o trips asociados
-- (ON DELETE RESTRICT / relación N:N con route_stops en cascada solo desde el lado routes).


-- ============================================================================
-- 2. DRIVERS
-- ============================================================================

-- CREATE
INSERT INTO drivers (name, id_number, license, hire_date)
VALUES ($1, $2, $3, $4)
RETURNING id;

-- READ (todos)
SELECT id, name, id_number, license, hire_date FROM drivers ORDER BY id;

-- READ (por id)
SELECT id, name, id_number, license, hire_date FROM drivers WHERE id = $1;

-- UPDATE
UPDATE drivers
SET name = $1, id_number = $2, license = $3, hire_date = $4
WHERE id = $5;

-- DELETE
DELETE FROM drivers WHERE id = $1;
-- Nota: fallará si el chofer tiene trips asociados (ON DELETE RESTRICT).


-- ============================================================================
-- 3. SCHEDULES
-- ============================================================================

-- CREATE
INSERT INTO schedules (route_id, scheduled_departure_time, scheduled_arrival_time)
VALUES ($1, $2, $3)
RETURNING id;

-- READ (todos, con nombre de ruta)
SELECT s.id, r.name AS route_name, s.scheduled_departure_time, s.scheduled_arrival_time
FROM schedules s
JOIN routes r ON r.id = s.route_id
ORDER BY s.id;

-- READ (por id)
SELECT id, route_id, scheduled_departure_time, scheduled_arrival_time
FROM schedules WHERE id = $1;

-- READ (por ruta)
SELECT id, route_id, scheduled_departure_time, scheduled_arrival_time
FROM schedules WHERE route_id = $1;

-- UPDATE
UPDATE schedules
SET route_id = $1, scheduled_departure_time = $2, scheduled_arrival_time = $3
WHERE id = $4;

-- DELETE
DELETE FROM schedules WHERE id = $1;
-- Nota: fallará si el horario tiene trips asociados (ON DELETE RESTRICT).


-- ============================================================================
-- 4. STOPS
-- ============================================================================

-- CREATE
INSERT INTO stops (name, latitude, longitude)
VALUES ($1, $2, $3)
RETURNING id;

-- READ (todas)
SELECT id, name, latitude, longitude FROM stops ORDER BY id;

-- READ (por id)
SELECT id, name, latitude, longitude FROM stops WHERE id = $1;

-- UPDATE
UPDATE stops
SET name = $1, latitude = $2, longitude = $3
WHERE id = $4;

-- DELETE
DELETE FROM stops WHERE id = $1;
-- Nota: fallará si la parada está usada en route_stops (ON DELETE RESTRICT).


-- ============================================================================
-- 5. ROUTE_STOPS (tabla puente, PK compuesta)
-- ============================================================================

-- CREATE
INSERT INTO route_stops (route_id, stop_id, stop_order, estimated_arrival_time)
VALUES ($1, $2, $3, $4);

-- READ (recorrido completo de una ruta, en orden)
SELECT rs.stop_order, s.name AS stop_name, rs.estimated_arrival_time
FROM route_stops rs
JOIN stops s ON s.id = rs.stop_id
WHERE rs.route_id = $1
ORDER BY rs.stop_order;

-- READ (por PK compuesta)
SELECT route_id, stop_id, stop_order, estimated_arrival_time
FROM route_stops WHERE route_id = $1 AND stop_id = $2;

-- UPDATE
UPDATE route_stops
SET stop_order = $1, estimated_arrival_time = $2
WHERE route_id = $3 AND stop_id = $4;

-- DELETE
DELETE FROM route_stops WHERE route_id = $1 AND stop_id = $2;


-- ============================================================================
-- 6. UNITS (padre MOR) + BUS / TRAIN / METRO (hijos)
-- ============================================================================

-- CREATE (unidad genérica, sin especializar — poco común, normalmente se inserta en la hija)
INSERT INTO units (plate_number, capacity, year, status, gps_id)
VALUES ($1, $2, $3, $4, $5)
RETURNING id;

-- CREATE (bus)
INSERT INTO bus (plate_number, capacity, year, status, gps_id, fuel_type, num_floors)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id;

-- CREATE (train)
INSERT INTO train (plate_number, capacity, year, status, gps_id, num_wagons, voltage)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id;

-- CREATE (metro)
INSERT INTO metro (plate_number, capacity, year, status, gps_id, line, num_wagons)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id;

-- READ (TODAS las unidades sin importar el tipo, gracias a la herencia)
SELECT id, plate_number, capacity, year, status, gps_id, tableoid::regclass AS unit_type
FROM units
ORDER BY id;
-- tableoid::regclass muestra de qué tabla hija viene cada fila (bus/train/metro/units)

-- READ (solo buses)
SELECT id, plate_number, capacity, year, status, gps_id, fuel_type, num_floors
FROM bus ORDER BY id;

-- READ (solo trenes)
SELECT id, plate_number, capacity, year, status, gps_id, num_wagons, voltage
FROM train ORDER BY id;

-- READ (solo metros)
SELECT id, plate_number, capacity, year, status, gps_id, line, num_wagons
FROM metro ORDER BY id;

-- READ (una unidad por id, sin importar el tipo)
SELECT id, plate_number, capacity, year, status, gps_id, tableoid::regclass AS unit_type
FROM units WHERE id = $1;

-- UPDATE (campos comunes; se actualiza sobre units y aplica a la fila real,
--         sin importar si vive físicamente en bus/train/metro)
UPDATE units
SET status = $1, gps_id = $2
WHERE id = $3;

-- UPDATE (campo específico de bus -> debe hacerse directo sobre la tabla hija)
UPDATE bus SET fuel_type = $1, num_floors = $2 WHERE id = $3;

-- UPDATE (campo específico de train)
UPDATE train SET num_wagons = $1, voltage = $2 WHERE id = $3;

-- UPDATE (campo específico de metro)
UPDATE metro SET line = $1, num_wagons = $2 WHERE id = $3;

-- DELETE (elimina la unidad sin importar el tipo; sensors se elimina en cascada,
--         trips/sensors con FK RESTRICT bloquean el borrado si hay historial)
DELETE FROM units WHERE id = $1;


-- ============================================================================
-- 7. SENSORS
-- ============================================================================
-- unit_id no tiene FK nativa (ver 01_ddl_smart_transit.sql, sección 8): la
-- validación de que la unidad exista la hace un trigger (fn_check_unit_exists),
-- que sí funciona correctamente al insertar/actualizar (probado contra Postgres).

-- CREATE
INSERT INTO sensors (unit_id, type, configuration)
VALUES ($1, $2, $3::jsonb)
RETURNING id;
-- Ejemplo:
-- INSERT INTO sensors (unit_id, type, configuration)
-- VALUES (1, 'GPS', '{"modelo":"GPS-4500X","frecuencia_muestreo_segundos":10,"umbral_alerta_velocidad":80}'::jsonb)
-- RETURNING id;

-- READ (todos)
SELECT id, unit_id, type, configuration FROM sensors ORDER BY id;

-- READ (por unidad)
SELECT id, type, configuration FROM sensors WHERE unit_id = $1;

-- READ (filtrando dentro del JSONB, ej. sensores con umbral de velocidad > 70)
SELECT id, unit_id, type, configuration
FROM sensors
WHERE (configuration->>'umbral_alerta_velocidad')::numeric > 70;

-- UPDATE
UPDATE sensors
SET type = $1, configuration = $2::jsonb
WHERE id = $3;

-- UPDATE (solo una clave dentro del JSONB, sin reemplazar todo el objeto)
UPDATE sensors
SET configuration = jsonb_set(configuration, '{umbral_alerta_velocidad}', $1::jsonb)
WHERE id = $2;

-- DELETE
DELETE FROM sensors WHERE id = $1;


-- ============================================================================
-- 8. TRIPS (tabla central)
-- ============================================================================
-- unit_id no tiene FK nativa por la misma razón que sensors; se valida por trigger.

-- CREATE
INSERT INTO trips (route_id, unit_id, driver_id, schedule_id, actual_departure_time, actual_arrival_time)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id;

-- READ (todos, con datos legibles de las tablas relacionadas)
SELECT
    t.id,
    r.name  AS route_name,
    u.plate_number,
    d.name  AS driver_name,
    t.actual_departure_time,
    t.actual_arrival_time
FROM trips t
JOIN routes  r ON r.id = t.route_id
JOIN units   u ON u.id = t.unit_id
JOIN drivers d ON d.id = t.driver_id
ORDER BY t.id;

-- READ (por id)
SELECT id, route_id, unit_id, driver_id, schedule_id, actual_departure_time, actual_arrival_time
FROM trips WHERE id = $1;

-- READ (viajes con atraso, comparando contra el horario programado)
SELECT
    t.id,
    r.name AS route_name,
    s.scheduled_departure_time,
    t.actual_departure_time,
    EXTRACT(EPOCH FROM (t.actual_departure_time::time - s.scheduled_departure_time)) / 60 AS delay_minutes
FROM trips t
JOIN schedules s ON s.id = t.schedule_id
JOIN routes r     ON r.id = t.route_id
WHERE t.actual_departure_time::time > s.scheduled_departure_time
ORDER BY delay_minutes DESC;

-- UPDATE
UPDATE trips
SET route_id = $1, unit_id = $2, driver_id = $3, schedule_id = $4,
    actual_departure_time = $5, actual_arrival_time = $6
WHERE id = $7;

-- UPDATE (registrar solo la hora de llegada real, caso de uso común)
UPDATE trips SET actual_arrival_time = $1 WHERE id = $2;

-- DELETE
DELETE FROM trips WHERE id = $1;
-- Nota: elimina en cascada los delay_report/incident_report asociados (ON DELETE CASCADE).


-- ============================================================================
-- 9. OFFICIAL_REPORTS (padre MOR) + DELAY_REPORT / INCIDENT_REPORT (hijos)
-- ============================================================================

-- CREATE (delay_report)
INSERT INTO delay_report (date, issuing_authority, xml_content, trip_id, delay_minutes, cause)
VALUES ($1, $2, $3::xml, $4, $5, $6)
RETURNING id;

-- CREATE (incident_report)
INSERT INTO incident_report (date, issuing_authority, xml_content, trip_id, severity, description)
VALUES ($1, $2, $3::xml, $4, $5, $6)
RETURNING id;

-- READ (TODOS los reportes oficiales, sin importar el tipo, gracias a la herencia)
SELECT id, date, issuing_authority, xml_content, tableoid::regclass AS report_type
FROM official_reports
ORDER BY id;

-- READ (solo reportes de atraso)
SELECT id, date, issuing_authority, trip_id, delay_minutes, cause
FROM delay_report ORDER BY id;

-- READ (solo reportes de incidente)
SELECT id, date, issuing_authority, trip_id, severity, description
FROM incident_report ORDER BY id;

-- READ (reportes de un viaje específico, combinando ambos tipos)
SELECT id, date, issuing_authority, 'delay' AS report_type, delay_minutes::text AS detail
FROM delay_report WHERE trip_id = $1
UNION ALL
SELECT id, date, issuing_authority, 'incident' AS report_type, severity AS detail
FROM incident_report WHERE trip_id = $1
ORDER BY date;

-- UPDATE (delay_report)
UPDATE delay_report
SET issuing_authority = $1, delay_minutes = $2, cause = $3
WHERE id = $4;

-- UPDATE (incident_report)
UPDATE incident_report
SET issuing_authority = $1, severity = $2, description = $3
WHERE id = $4;

-- DELETE (delay_report)
DELETE FROM delay_report WHERE id = $1;

-- DELETE (incident_report)
DELETE FROM incident_report WHERE id = $1;
