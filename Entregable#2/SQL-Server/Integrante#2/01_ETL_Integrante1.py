# ETL - Integrante #1
# PostgreSQL + MongoDB -> SQL Server
#
# Antes de ejecutar:
# 1. Levantar PostgreSQL, MongoDB y SQL Server.
# 2. Crear la base MobilityAnalysis.
# 3. Ejecutar 02_SQL_Server_Mongo.sql en SQL Server.
# 4. Cambiar las contraseñas/conexiones de este archivo.
#
# Instalar una sola vez:
# pip install psycopg2-binary pymongo pyodbc

import psycopg2
from pymongo import MongoClient
import pyodbc
from datetime import datetime

# ---------- CONEXIONES ----------
PG = {
    "host": "localhost",
    "port": 5432,
    "database": "TransportePublico",
    "user": "postgres",
    "password": "Utn123**"
}

MONGO_URL = "mongodb://admin:Utn123**@localhost:27017/?authSource=admin"
MONGO_DATABASE = "test"

SQL_SERVER = "Laptop-Laura"
SQL_DATABASE = "MobilityAnalysis"


# ---------- POSTGRESQL ----------
def cargar_postgresql():
    pg = psycopg2.connect(**PG)
    sql = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};"
        f"SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )

    pg_cursor = pg.cursor()
    sql_cursor = sql.cursor()

    # Rutas
    pg_cursor.execute("""
        SELECT id, name, origin, destination, distance_km
        FROM routes
    """)
    for r in pg_cursor.fetchall():
        sql_cursor.execute("""
            IF NOT EXISTS (SELECT 1 FROM DIM_ROUTE WHERE name = ?)
            INSERT INTO DIM_ROUTE(name, origin, destination, distance_km)
            VALUES (?, ?, ?, ?)
        """, r[1], r[1], r[2], r[3], r[4])

    # Conductores
    pg_cursor.execute("""
        SELECT id, name, id_number, license
        FROM drivers
    """)
    for d in pg_cursor.fetchall():
        sql_cursor.execute("""
            IF NOT EXISTS (SELECT 1 FROM DIM_DRIVER WHERE id_number = ?)
            INSERT INTO DIM_DRIVER(name, id_number, license)
            VALUES (?, ?, ?)
        """, d[2], d[1], d[2], d[3])

    # Unidades: SELECT sobre units incluye las filas heredadas
    # de bus, train y metro en PostgreSQL.
    pg_cursor.execute("""
        SELECT id, plate_number, gps_id, capacity, year, status
        FROM units
    """)
    for u in pg_cursor.fetchall():
        # Determinamos el tipo de unidad con una consulta sencilla.
        pg_cursor.execute("SELECT 1 FROM bus WHERE id = %s", (u[0],))
        tipo = "bus" if pg_cursor.fetchone() else None

        if tipo is None:
            pg_cursor.execute("SELECT 1 FROM train WHERE id = %s", (u[0],))
            tipo = "train" if pg_cursor.fetchone() else None

        if tipo is None:
            pg_cursor.execute("SELECT 1 FROM metro WHERE id = %s", (u[0],))
            tipo = "metro" if pg_cursor.fetchone() else "unit"

        sql_cursor.execute("""
            IF NOT EXISTS (SELECT 1 FROM DIM_UNIT WHERE gps_id = ?)
            INSERT INTO DIM_UNIT(plate, gps_id, capacity, year, status, unit_type)
            VALUES (?, ?, ?, ?, ?, ?)
        """, u[2], u[1], u[2], u[3], u[4], u[5], tipo)

    # Viajes
    pg_cursor.execute("""
        SELECT id, route_id, unit_id, driver_id, schedule_id,
               actual_departure_time, actual_arrival_time
        FROM trips
    """)
    viajes = pg_cursor.fetchall()

    for t in viajes:
        # El ID de PostgreSQL no necesariamente coincide con SQL Server,
        # por lo que usamos el nombre de la ruta.
        pg_cursor.execute(
            "SELECT name FROM routes WHERE id = %s", (t[1],)
        )
        ruta = pg_cursor.fetchone()[0]
        sql_cursor.execute(
            "SELECT id_route FROM DIM_ROUTE WHERE name = ?", ruta
        )
        id_route = sql_cursor.fetchone()[0]

        pg_cursor.execute(
            "SELECT id_number FROM drivers WHERE id = %s", (t[3],)
        )
        id_number = pg_cursor.fetchone()[0]
        sql_cursor.execute(
            "SELECT id_driver FROM DIM_DRIVER WHERE id_number = ?",
            id_number
        )
        id_driver = sql_cursor.fetchone()[0]

        pg_cursor.execute(
            "SELECT gps_id FROM units WHERE id = %s", (t[2],)
        )
        gps_id = pg_cursor.fetchone()[0]
        sql_cursor.execute(
            "SELECT id_unit FROM DIM_UNIT WHERE gps_id = ?", gps_id
        )
        id_unit = sql_cursor.fetchone()[0]

        pg_cursor.execute("""
            SELECT scheduled_departure_time, scheduled_arrival_time
            FROM schedules
            WHERE id = %s
        """, (t[4],))
        horario = pg_cursor.fetchone()

        fecha = t[5].date()
        id_date = int(fecha.strftime("%Y%m%d"))

        # Crear fecha en DIM_DATE si todavía no existe.
        sql_cursor.execute("""
            IF NOT EXISTS (SELECT 1 FROM DIM_DATE WHERE id_date = ?)
            INSERT INTO DIM_DATE(id_date, full_date, is_weekend,
                                 day_of_week, month, year)
            VALUES (?, ?, ?, ?, ?, ?)
        """,
        id_date, id_date, fecha,
        1 if fecha.weekday() >= 5 else 0,
        fecha.strftime("%A"), fecha.month, fecha.year)

        duracion = int((t[6] - t[5]).total_seconds() / 60)
        atraso = int((t[5].hour * 60 + t[5].minute) -
                     (horario[0].hour * 60 + horario[0].minute))
        velocidad = 0
        # La distancia de la ruta se obtiene de SQL Server.
        sql_cursor.execute(
            "SELECT distance_km FROM DIM_ROUTE WHERE id_route = ?",
            id_route
        )
        distancia = float(sql_cursor.fetchone()[0])
        if duracion > 0:
            velocidad = round(distancia / (duracion / 60), 2)

        puntual = 1 if atraso <= 5 else 0

        sql_cursor.execute("""
            IF NOT EXISTS
            (SELECT 1 FROM FACT_TRIP_HISTORY WHERE id_trip_source = ?)
            INSERT INTO FACT_TRIP_HISTORY
            (id_trip_source, id_date, id_route, id_unit, id_driver,
             scheduled_departure, actual_departure,
             scheduled_arrival, actual_arrival,
             trip_duration_min, delay_min, distance_traveled_km,
             average_speed_kmh, on_time)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        t[0], t[0], id_date, id_route, id_unit, id_driver,
        horario[0], t[5].time(), horario[1], t[6].time(),
        duracion, atraso, distancia, velocidad, puntual)

    sql.commit()
    pg.close()
    sql.close()
    print("PostgreSQL -> SQL Server: carga terminada.")


# ---------- MONGODB ----------
def cargar_mongodb():
    mongo = MongoClient(MONGO_URL)
    coleccion = mongo[MONGO_DATABASE]["eventos_gps"]

    sql = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};"
        f"SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )
    cursor = sql.cursor()

    for e in coleccion.find():
        gps = e["gpsId"]

        cursor.execute(
            "SELECT id_unit FROM DIM_UNIT WHERE gps_id = ?", gps
        )
        unidad = cursor.fetchone()

        if unidad:
            fecha = datetime.fromisoformat(
                e["timestamp"].replace("Z", "+00:00")
            ).replace(tzinfo=None)
            id_date = int(fecha.strftime("%Y%m%d"))

            cursor.execute("""
                IF NOT EXISTS
                (SELECT 1 FROM FACT_GPS_EVENT
                 WHERE source_id = ?)
                INSERT INTO FACT_GPS_EVENT
                (source_id, id_date, id_unit, event_timestamp,
                 latitude, longitude, speed, direction,
                 engine, engine_temperature, fuel)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            str(e["_id"]), str(e["_id"]), id_date, unidad[0],
            fecha,
            e["location"]["latitude"],
            e["location"]["longitude"],
            e["telemetry"]["speed"],
            e["telemetry"]["direction"],
            e["telemetry"]["engine"],
            e["telemetry"]["engineTemperature"],
            e["telemetry"]["fuel"])

    sql.commit()
    mongo.close()
    sql.close()
    print("MongoDB -> SQL Server: carga terminada.")


if __name__ == "__main__":
    cargar_postgresql()
    cargar_mongodb()
    print("ETL completo.")
