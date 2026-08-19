INSERT INTO routes (name, origin, destination, distance_km) VALUES
('Ruta 1 - Circuito Central', 'Terminal Central', 'Aeropuerto', 18.40),
('Ruta 2 - Circuito Norte-Sur', 'Estación Norte', 'Estación Sur', 22.75),
('Ruta 3 - Circuito Metro', 'Terminal Central', 'Universidad', 9.30);

INSERT INTO stops (name, latitude, longitude) VALUES
('Terminal Central', 9.933333, -84.083333),
('Universidad', 9.936000, -84.051000),
('Hospital', 9.928500, -84.090200),
('Aeropuerto', 9.993800, -84.208800),
('Centro Comercial', 9.941200, -84.076500),
('Parque Central', 9.932900, -84.079100),
('Estación Norte', 9.965400, -84.088700),
('Estación Sur', 9.901200, -84.075600);

INSERT INTO route_stops (route_id, stop_id, stop_order, estimated_arrival_time) VALUES
(1, 1, 1, '06:00'),
(1, 2, 2, '06:20'),
(1, 3, 3, '06:40'),
(1, 4, 4, '07:00'),
(2, 7, 1, '07:30'),
(2, 6, 2, '08:00'),
(2, 5, 3, '08:30'),
(2, 8, 4, '09:00'),
(3, 1, 1, '08:00'),
(3, 5, 2, '08:20'),
(3, 2, 3, '08:40');

INSERT INTO schedules (route_id, scheduled_departure_time, scheduled_arrival_time) VALUES
(1, '06:00', '07:00'),
(2, '07:30', '09:00'),
(3, '08:00', '08:40');

INSERT INTO drivers (name, id_number, license, hire_date) VALUES
('Carlos Rodríguez Mora', '1-1234-5678', 'B1', '2019-03-10'),
('María Fernanda Solís', '2-2345-6789', 'B2', '2021-06-01'),
('José Luis Vargas', '3-3456-7890', 'B1', '2018-11-20');

INSERT INTO bus (plate_number, capacity, year, status, gps_id, fuel_type, num_floors) VALUES
('BUS-101', 45, 2019, 'active', 'GPS-BUS-101', 'diesel', 1);

INSERT INTO train (plate_number, capacity, year, status, gps_id, num_wagons, voltage) VALUES
('TRN-201', 220, 2015, 'active', 'GPS-TRN-201', 4, 750.00);

INSERT INTO metro (plate_number, capacity, year, status, gps_id, line, num_wagons) VALUES
('MET-301', 300, 2022, 'active', 'GPS-MET-301', 'Línea 1', 6);

INSERT INTO sensors (unit_id, type, configuration) VALUES
(1, 'GPS', '{"modelo":"GPS-4500X","frecuencia_muestreo_segundos":10,"umbral_alerta_velocidad":80}'),
(1, 'Combustible', '{"modelo":"FUEL-200","capacidad_tanque_litros":150,"umbral_nivel_bajo":15}'),
(2, 'GPS', '{"modelo":"GPS-4500X","frecuencia_muestreo_segundos":5,"umbral_alerta_velocidad":100}'),
(2, 'Voltaje', '{"modelo":"VOLT-900","voltaje_nominal":750,"umbral_alerta":650}'),
(3, 'GPS', '{"modelo":"GPS-5000","frecuencia_muestreo_segundos":5,"umbral_alerta_velocidad":90}');

INSERT INTO trips (route_id, unit_id, driver_id, schedule_id, actual_departure_time, actual_arrival_time) VALUES
(1, 1, 1, 1, '2026-08-03 06:08:00', '2026-08-03 07:15:00'),
(3, 3, 3, 3, '2026-08-03 08:01:00', '2026-08-03 08:37:00'),
(2, 2, 2, 2, '2026-08-03 07:32:00', '2026-08-03 08:58:00'),
(1, 1, 1, 1, '2026-08-04 06:00:00', '2026-08-04 07:20:00'),
(2, 2, 2, 2, '2026-08-04 07:45:00', '2026-08-04 09:35:00');

INSERT INTO delay_report (date, issuing_authority, xml_content, trip_id, delay_minutes, cause) VALUES
('2026-08-03', 'Municipalidad', '<report><type>delay</type><trip>1</trip></report>', 1, 8, 'Tráfico en Avenida Central'),
('2026-08-04', 'Municipalidad', '<report><type>delay</type><trip>5</trip></report>', 5, 35, 'Congestión vehicular por lluvia');

INSERT INTO incident_report (date, issuing_authority, xml_content, trip_id, severity, description) VALUES
('2026-08-03', 'Municipalidad', '<report><type>incident</type><trip>3</trip></report>', 3, 'low', 'Puerta con falla eléctrica, resuelta en estación'),
('2026-08-04', 'Municipalidad', '<report><type>incident</type><trip>4</trip></report>', 4, 'medium', 'Falla en el sistema de frenos, revisión en ruta');