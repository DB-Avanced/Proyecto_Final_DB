# MongoDB - Colección `eventos_gps`

## Descripción

La colección **`eventos_gps`** almacena los eventos de geolocalización y telemetría generados por las unidades de transporte público durante su operación.

Cada documento representa un **evento puntual**, capturado en un instante específico, enviado por el dispositivo GPS instalado en una unidad.

Debido a que estos datos son generados continuamente (cada pocos segundos), MongoDB resulta una base de datos adecuada gracias a su flexibilidad, capacidad para almacenar grandes volúmenes de información y alto rendimiento en operaciones de escritura.

---

# Justificación del uso de MongoDB

Los datos GPS presentan características diferentes a los datos administrativos almacenados en PostgreSQL.

Mientras PostgreSQL administra información estructurada y relativamente estable (rutas, choferes, horarios y unidades), los eventos GPS generan miles de registros durante un solo día de operación.

MongoDB permite almacenar estos eventos como documentos independientes sin necesidad de realizar múltiples relaciones entre tablas, lo que reduce la complejidad y mejora el rendimiento para datos de alta frecuencia.

Además, el esquema flexible permite incorporar nuevos sensores en el futuro sin modificar la estructura de la base de datos.

---

# Objetivo de la colección

Registrar en tiempo real:

- Ubicación actual de cada unidad.
- Velocidad de desplazamiento.
- Dirección del vehículo.
- Estado del motor.
- Información adicional proveniente de sensores (telemetría).

Estos datos servirán posteriormente para alimentar el proceso ETL encargado de generar información histórica para análisis de movilidad.

---

# Nombre de la colección

```
events_gps
```

---

# Estructura del documento

```json
{
  "gpsId": "string",
  "timestamp": "string",
  "location": {
    "latitude": "number",
    "longitude": "number"
  },
  "telemetry": {
    "speed": "number",
    "direction": "number",
    "engine": "string",
    "engineTemperature": "number",
    "fuel": "number"
  }
}
```

---

# Descripción de los atributos

| Campo | Tipo | Descripción |
|---------|------|-------------|
| gpsId | String | Identificador único del dispositivo GPS instalado en la unidad. Permite relacionar el evento con la unidad registrada en PostgreSQL. |
| timestamp | Date | Fecha y hora exacta en que se generó el evento. |
| ubicacion.latitud | Decimal | Latitud obtenida por el GPS. |
| ubicacion.longitud | Decimal | Longitud obtenida por el GPS. |
| telemetria.velocidad | Número | Velocidad instantánea del vehículo (km/h). |
| telemetria.direccion | Número | Dirección o rumbo del vehículo expresado en grados (0°–359°). |
| telemetria.motor | String | Estado del motor (ENCENDIDO / APAGADO). |
| telemetria.temperaturaMotor | Número | Temperatura del motor en grados Celsius. |
| telemetria.combustible | Número | Nivel de combustible expresado como porcentaje. |

---

# ¿Qué es la telemetría?

La telemetría consiste en la transmisión remota de información generada por sensores instalados en un vehículo.

En este proyecto, la telemetría complementa la información de geolocalización proporcionando datos operativos de la unidad.

Entre ellos:

- Velocidad.
- Dirección.
- Estado del motor.
- Temperatura del motor.
- Nivel de combustible.

La estructura propuesta permite agregar nuevos sensores sin modificar el esquema de la colección.

Por ejemplo:

- ocupacion
- bateria
- puertasAbiertas
- presionAceite
- consumoInstantaneo

---

# Relación con PostgreSQL

La colección **no almacena** información administrativa como:

- placa
- ruta
- chofer
- horario

Esa información ya existe en PostgreSQL.

Cada evento únicamente almacena el identificador del dispositivo GPS (`gpsId`).

En PostgreSQL se añadió el atributo:

```
unidades

id
placa
capacidad
gps_id
anio
estado
```

De esta manera, el proceso ETL puede identificar fácilmente a qué unidad pertenece cada evento.

---

# Flujo de información

```
Autobús
     │
     │
GPS + Sensores
     │
     ▼
Evento GPS
     │
     ▼
MongoDB
(eventos_gps)
     │
     ▼
Proceso ETL
     │
     ├── Consulta PostgreSQL
     │      (unidad, ruta, chofer, horario)
     │
     ▼
SQL Server
(Análisis histórico de movilidad)
```

---

# Integración mediante ETL

El proceso ETL realiza tres etapas principales.

## 1. Extract

Obtiene los eventos almacenados en la colección `eventos_gps`.

Ejemplo:

```
GPS-001
08:30
Latitud
Longitud
Velocidad
```

---

## 2. Transform

Consulta PostgreSQL utilizando el campo `gpsId`.

Ejemplo:

```
gpsId = GPS-001

↓

Unidad 15

↓

Ruta 4

↓

Chofer Juan Pérez

↓

Horario 08:00 - 16:00
```

Durante esta etapa también pueden calcularse indicadores como:

- tiempo de recorrido
- velocidad promedio
- retrasos
- cumplimiento del horario
- tiempo entre paradas

---

## 3. Load

La información enriquecida se almacena en SQL Server para realizar consultas históricas y generar reportes.

Ejemplos:

- promedio de velocidad por ruta
- rutas con mayor congestión
- tiempo promedio de viaje
- porcentaje de atrasos
- análisis de movilidad por horario

---

# Ventajas del modelo propuesto

- Separación entre datos operativos y administrativos.
- Alta capacidad para almacenar grandes volúmenes de eventos.
- Flexibilidad para incorporar nuevos sensores.
- Baja complejidad del modelo documental.
- Integración sencilla mediante el identificador `gpsId`.
- Escalabilidad para registrar millones de eventos diarios.

---

# Conclusión

La colección **`eventos_gps`** centraliza la información de geolocalización y telemetría generada por las unidades de transporte durante su operación.

Su diseño permite almacenar eventos de manera eficiente en MongoDB, mientras que la información administrativa permanece normalizada en PostgreSQL. Finalmente, mediante un proceso ETL, ambos conjuntos de datos se integran para construir el histórico de movilidad almacenado en SQL Server, permitiendo realizar análisis sobre tiempos de viaje, atrasos, velocidad promedio y optimización de rutas.