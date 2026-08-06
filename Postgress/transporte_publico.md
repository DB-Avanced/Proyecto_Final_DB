# Documentación de diseño de base de datos
## Escenario 3: Transporte Público Inteligente

---

## 1. Situación / Problema

La municipalidad requiere monitorear rutas, unidades y tiempos de viaje. Actualmente no puede medir atrasos ni optimizar recorridos utilizando datos históricos.

**Requisitos identificados en el enunciado:**

1. Monitorear rutas, unidades y tiempos de viaje.
2. Medir atrasos (comparar tiempo programado vs. tiempo real).
3. Optimizar recorridos con datos históricos.
4. Fuente PostgreSQL: Rutas, Choferes, Horarios, Unidades.
5. Fuente JSON: Configuración de sensores.
6. Fuente XML: Reportes oficiales.

**Conclusión del análisis inicial:** el enunciado no solo pide catálogos (rutas, choferes, horarios, unidades) — pide eventos históricos que permitan calcular métricas. Modelar solo catálogos no responde la pregunta de negocio, por lo que se agregaron entidades adicionales (paradas, viajes, sensores, reportes) no explícitas en el enunciado pero necesarias para cumplir los requisitos.

---

## 2. Arquitectura general del sistema

El sistema combina **tres tecnologías de almacenamiento**, cada una con un rol distinto:

| Tecnología | Rol | Contenido |
|---|---|---|
| **PostgreSQL** | Base transaccional/relacional principal | Catálogos, eventos de viaje, reportes oficiales |
| **JSON (JSONB en Postgres)** | Configuración semi-estructurada | Configuración de sensores (embebido en `sensors.configuration`) |
| **XML** | Documentos oficiales | Contenido de reportes oficiales (embebido en `official_reports` / hijos) |


---

## 3. Modelo relacional en PostgreSQL

### 3.1 Tablas de catálogo (maestras)

**`routes`**
- `id` (PK)
- `name`
- `origin`
- `destination`
- `distance_km`

**`drivers`**
- `id` (PK)
- `name`
- `id_number`
- `license`
- `hire_date`

**`schedules`**
- `id` (PK)
- `route_id` (FK → routes)
- `scheduled_departure_time`
- `scheduled_arrival_time`

**`stops`**
- `id` (PK)
- `name`
- `latitude`
- `longitude`

### 3.2 Tabla puente (relación N:N)

**`route_stops`**
- `route_id` (FK → routes)
- `stop_id` (FK → stops)
- `stop_order`
- `estimated_arrival_time`
- PK compuesta: (`route_id`, `stop_id`)

**Justificación:** una ruta pasa por varias paradas y una parada puede pertenecer a varias rutas (relación muchos a muchos). No se puede resolver con una FK directa; se requiere tabla intermedia. El campo `stop_order` es indispensable para reconstruir la secuencia real del recorrido.

### 3.3 Jerarquía MOR — Unidades

**`units`** (tabla padre)
- `id` (PK)
- `plate_number`
- `capacity`
- `year`
- `status`
- `gps_id` — identificador del dispositivo GPS físico instalado en la unidad, usado para enlazar con MongoDB

**`bus`** (hijo de `units`)
- `fuel_type`
- `num_floors`

**`train`** (hijo de `units`)
- `num_wagons`
- `voltage`

**`metro`** (hijo de `units`)
- `line`
- `num_wagons`

**Nota técnica:** se usa herencia de tablas de PostgreSQL (`CREATE TABLE hijo () INHERITS (padre)`). Esto permite que `SELECT * FROM units` traiga todas las unidades sin importar el tipo, y que cada hija tenga sus atributos específicos. Las FK definidas en las tablas hijas **no se heredan automáticamente** al padre — es una limitación conocida de la herencia en Postgres, y quedó como punto abierto si se requiere lógica adicional (constraints por hija o triggers).

### 3.4 Tabla de sensores (catálogo/configuración)

**`sensors`**
- `id` (PK)
- `unit_id` (FK → units)
- `type`
- `configuration` (JSONB)

**Qué va dentro de `configuration`:** parámetros de configuración del sensor (no telemetría). Ejemplo:

```json
{
  "modelo": "GPS-4500X",
  "frecuencia_muestreo_segundos": 10,
  "umbral_alerta_velocidad": 80,
  "unidad_medida": "km/h",
  "calibracion_offset": 0.002,
  "protocolo_comunicacion": "MQTT"
}
```

Se usa JSONB porque cada tipo de sensor tiene configuración distinta (GPS, combustible, temperatura de motor, etc.); usar columnas fijas generaría muchos campos NULL según el tipo.

**Distinción clave:**

| Concepto | Qué es | Dónde vive |
|---|---|---|
| Configuración del sensor | Metadata: qué sensor existe, en qué unidad, cómo está calibrado | PostgreSQL (`sensors`) — catálogo, bajo volumen |
| Telemetría / eventos del sensor | Lecturas reales generadas segundo a segundo | MongoDB  — alto volumen, streaming |

### 3.5 Tabla central de eventos

**`trips`**
- `id` (PK)
- `route_id` (FK → routes)
- `unit_id` (FK → units)
- `driver_id` (FK → drivers)
- `schedule_id` (FK → schedules)
- `actual_departure_time`
- `actual_arrival_time`

**Por qué es la tabla más importante del modelo:** registra lo que realmente ocurrió (hora real) en contraste con lo planificado (`schedules`). Sin esta tabla no es posible calcular atrasos ni tener datos históricos de operación.

### 3.6 Jerarquía MOR — Reportes oficiales

**`official_reports`** (tabla padre)
- `id` (PK)
- `date`
- `issuing_authority`
- `xml_content`

**`delay_report`** (hijo)
- `trip_id` (FK → trips)
- `delay_minutes`
- `cause`

**`incident_report`** (hijo)
- `trip_id` (FK → trips)
- `severity`
- `description`

**Justificación:** ambos hijos comparten metadatos (fecha, autoridad emisora, contenido XML) pero difieren en el detalle específico del evento. `SELECT * FROM official_reports` trae todo unificado (atrasos + incidentes) para análisis histórico general, mientras que cada hija responde una pregunta de negocio específica.

---

## 4. Relaciones generales del modelo

- `routes` 1:N `schedules`
- `routes` N:N `stops` (vía `route_stops`, con orden)
- `trips` N:1 `routes`
- `trips` N:1 `units` (bus/train/metro)
- `trips` N:1 `drivers`
- `trips` N:1 `schedules`
- `units` 1:N `sensors`
- `units` 1:1 `gps_id` (dispositivo físico, enlace lógico hacia MongoDB)
- `trips` 1:N `delay_report`
- `trips` 1:N `incident_report`

---

## 5. Diagrama entidad-relación
![alt text](<Diagrama_ProyectoBD-Postgres.png>)
---

## 6. Resumen — dónde vive cada requisito del enunciado

| Requisito original | Dónde vive |
|---|---|
| Rutas, Choferes, Horarios, Unidades | Tablas de catálogo en PostgreSQL |
| JSON: configuración de sensores | `sensors.configuration` (JSONB) |
| XML: reportes oficiales | `official_reports.xml_content` (y tablas hijas) |
| Medir atrasos | `trips` (comparado contra `schedules`) + `delay_report` |