-- ============================================================================
-- DDL - Escenario 3: Transporte Público Inteligente
-- Motor: PostgreSQL
-- PK: SERIAL (autoincremental clásico)
-- Jerarquía MOR: herencia real de PostgreSQL (INHERITS)
-- ============================================================================

-- CREATE TABLE TransportePublico

-- Limpieza (útil en desarrollo, comentar en producción)
DROP TABLE IF EXISTS incident_report CASCADE;
DROP TABLE IF EXISTS delay_report CASCADE;
DROP TABLE IF EXISTS official_reports CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS sensors CASCADE;
DROP TABLE IF EXISTS metro CASCADE;
DROP TABLE IF EXISTS train CASCADE;
DROP TABLE IF EXISTS bus CASCADE;
DROP TABLE IF EXISTS units CASCADE;
DROP TABLE IF EXISTS route_stops CASCADE;
DROP TABLE IF EXISTS schedules CASCADE;
DROP TABLE IF EXISTS stops CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS routes CASCADE;


-- ============================================================================
-- 1. TABLAS DE CATÁLOGO (maestras)
-- ============================================================================

CREATE TABLE routes (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    origin        VARCHAR(100) NOT NULL,
    destination   VARCHAR(100) NOT NULL,
    distance_km   NUMERIC(6,2) CHECK (distance_km > 0)
);

CREATE TABLE drivers (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    id_number   VARCHAR(20) NOT NULL UNIQUE,
    license     VARCHAR(30) NOT NULL,
    hire_date   DATE NOT NULL
);

CREATE TABLE schedules (
    id                         SERIAL PRIMARY KEY,
    route_id                   INTEGER NOT NULL REFERENCES routes(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    scheduled_departure_time   TIME NOT NULL,
    scheduled_arrival_time     TIME NOT NULL,
    CHECK (scheduled_arrival_time > scheduled_departure_time)
);

CREATE TABLE stops (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    latitude    NUMERIC(9,6) NOT NULL,
    longitude   NUMERIC(9,6) NOT NULL
);


-- ============================================================================
-- 2. TABLA PUENTE (relación N:N routes <-> stops)
-- ============================================================================

CREATE TABLE route_stops (
    route_id                INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE ON UPDATE CASCADE,
    stop_id                  INTEGER NOT NULL REFERENCES stops(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    stop_order               INTEGER NOT NULL CHECK (stop_order > 0),
    estimated_arrival_time   TIME,
    PRIMARY KEY (route_id, stop_id),
    UNIQUE (route_id, stop_order)   -- evita dos paradas con el mismo orden en la misma ruta
);


-- ============================================================================
-- 3. JERARQUÍA MOR - UNITS (herencia real de PostgreSQL)
-- ============================================================================

CREATE TABLE units (
    id             SERIAL PRIMARY KEY,
    plate_number   VARCHAR(15) NOT NULL UNIQUE,
    capacity       INTEGER NOT NULL CHECK (capacity > 0),
    year           INTEGER NOT NULL CHECK (year >= 1980),
    status         VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'inactive')),
    gps_id         VARCHAR(50) UNIQUE
);

-- Cada hija hereda TODAS las columnas de units: id, plate_number, capacity, year, status, gps_id
CREATE TABLE bus (
    fuel_type    VARCHAR(20) NOT NULL,
    num_floors   INTEGER NOT NULL DEFAULT 1 CHECK (num_floors IN (1, 2)),
    PRIMARY KEY (id)
) INHERITS (units);

CREATE TABLE train (
    num_wagons   INTEGER NOT NULL CHECK (num_wagons > 0),
    voltage      NUMERIC(6,2),
    PRIMARY KEY (id)
) INHERITS (units);

CREATE TABLE metro (
    "line"         VARCHAR(50) NOT NULL,
    num_wagons   INTEGER NOT NULL CHECK (num_wagons > 0),
    PRIMARY KEY (id)
) INHERITS (units);

-- NOTA CLAVE sobre INHERITS en PostgreSQL:
--   - Columnas y CHECK constraints del padre SÍ se heredan.
--   - PRIMARY KEY, UNIQUE y FOREIGN KEY del padre NO se heredan automáticamente
--     -> por eso se declara PRIMARY KEY (id) explícito en cada hija.
--   - La columna id usa el DEFAULT (secuencia units_id_seq) heredado del padre,
--     así que los ids siguen siendo únicos entre units, bus, train y metro.
--   - SELECT * FROM units        -> trae también las filas de bus/train/metro.
--   - SELECT * FROM ONLY units   -> trae solo filas insertadas directamente en units.


-- ============================================================================
-- 4. SENSORS (catálogo/configuración, relacionado al JSON)
-- ============================================================================

-- NOTA: unit_id NO lleva FOREIGN KEY nativa. Postgres no valida correctamente una FK
-- contra una tabla padre (units) cuando la fila referenciada vive físicamente en una
-- hija (bus/train/metro) por INHERITS. La integridad se garantiza con triggers
-- (ver sección 8 "INTEGRIDAD REFERENCIAL PARA LA JERARQUÍA UNITS").
CREATE TABLE sensors (
    id              SERIAL PRIMARY KEY,
    unit_id         INTEGER NOT NULL,
    type            VARCHAR(30) NOT NULL,
    configuration   JSONB NOT NULL DEFAULT '{}'::jsonb
);


-- ============================================================================
-- 5. TRIPS (tabla central de eventos)
-- ============================================================================

-- NOTA: unit_id NO lleva FOREIGN KEY nativa, por la misma razón que en sensors
-- (ver sección 8). Se valida con trigger.
CREATE TABLE trips (
    id                      SERIAL PRIMARY KEY,
    route_id                INTEGER NOT NULL REFERENCES routes(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    unit_id                 INTEGER NOT NULL,
    driver_id               INTEGER NOT NULL REFERENCES drivers(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    schedule_id              INTEGER NOT NULL REFERENCES schedules(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    actual_departure_time    TIMESTAMP NOT NULL,
    actual_arrival_time      TIMESTAMP,
    CHECK (actual_arrival_time IS NULL OR actual_arrival_time > actual_departure_time)
);


-- ============================================================================
-- 6. JERARQUÍA MOR - OFFICIAL_REPORTS (herencia real de PostgreSQL)
-- ============================================================================

CREATE TABLE official_reports (
    id                  SERIAL PRIMARY KEY,
    date                DATE NOT NULL DEFAULT CURRENT_DATE,
    issuing_authority   VARCHAR(100) NOT NULL,
    xml_content         XML
);

CREATE TABLE delay_report (
    trip_id         INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE ON UPDATE CASCADE,
    delay_minutes   INTEGER NOT NULL CHECK (delay_minutes > 0),
    cause           VARCHAR(200),
    PRIMARY KEY (id)
) INHERITS (official_reports);

CREATE TABLE incident_report (
    trip_id       INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE ON UPDATE CASCADE,
    severity      VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    description   TEXT,
    PRIMARY KEY (id)
) INHERITS (official_reports);


-- ============================================================================
-- 7. ÍNDICES RECOMENDADOS (adicionales a los implícitos por PK/UNIQUE)
-- ============================================================================

CREATE INDEX idx_schedules_route_id      ON schedules(route_id);
CREATE INDEX idx_route_stops_stop_id     ON route_stops(stop_id);
CREATE INDEX idx_sensors_unit_id         ON sensors(unit_id);
CREATE INDEX idx_trips_route_id          ON trips(route_id);
CREATE INDEX idx_trips_unit_id           ON trips(unit_id);
CREATE INDEX idx_trips_driver_id         ON trips(driver_id);
CREATE INDEX idx_trips_schedule_id       ON trips(schedule_id);
CREATE INDEX idx_delay_report_trip_id    ON delay_report(trip_id);
CREATE INDEX idx_incident_report_trip_id ON incident_report(trip_id);


-- ============================================================================
-- 8. INTEGRIDAD REFERENCIAL PARA LA JERARQUÍA UNITS (vía triggers)
-- ============================================================================
-- MOTIVO: PostgreSQL no soporta FOREIGN KEY nativas que referencien una tabla
-- padre (units) cuando la fila vive físicamente en una tabla hija (bus/train/metro)
-- por INHERITS. Se comprobó empíricamente: una FK "sensors.unit_id REFERENCES
-- units(id)" rechaza unit_id de filas que existen en bus/train/metro, aunque
-- "SELECT * FROM units" sí las muestra. Por eso se reemplaza la FK nativa por
-- validación en trigger, que sí usa correctamente el recorrido de la jerarquía.

-- 8.1 Validar que unit_id exista (en units o cualquiera de sus hijas) antes de
--     insertar/actualizar en sensors o trips.
CREATE OR REPLACE FUNCTION fn_check_unit_exists()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM units WHERE id = NEW.unit_id) THEN
        RAISE EXCEPTION 'unit_id % no existe en units (ni en bus/train/metro)', NEW.unit_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sensors_check_unit
    BEFORE INSERT OR UPDATE OF unit_id ON sensors
    FOR EACH ROW EXECUTE FUNCTION fn_check_unit_exists();

CREATE TRIGGER trg_trips_check_unit
    BEFORE INSERT OR UPDATE OF unit_id ON trips
    FOR EACH ROW EXECUTE FUNCTION fn_check_unit_exists();

-- 8.2 Simular el comportamiento de ON DELETE RESTRICT (trips) y ON DELETE CASCADE
--     (sensors) al borrar una unidad, sin importar en qué tabla física viva
--     (units, bus, train o metro).
CREATE OR REPLACE FUNCTION fn_unit_delete_guard()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM trips WHERE unit_id = OLD.id) THEN
        RAISE EXCEPTION 'No se puede eliminar la unidad %: tiene trips asociados', OLD.id;
    END IF;
    DELETE FROM sensors WHERE unit_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_units_delete_guard
    BEFORE DELETE ON units
    FOR EACH ROW EXECUTE FUNCTION fn_unit_delete_guard();
CREATE TRIGGER trg_bus_delete_guard
    BEFORE DELETE ON bus
    FOR EACH ROW EXECUTE FUNCTION fn_unit_delete_guard();
CREATE TRIGGER trg_train_delete_guard
    BEFORE DELETE ON train
    FOR EACH ROW EXECUTE FUNCTION fn_unit_delete_guard();
CREATE TRIGGER trg_metro_delete_guard
    BEFORE DELETE ON metro
    FOR EACH ROW EXECUTE FUNCTION fn_unit_delete_guard();