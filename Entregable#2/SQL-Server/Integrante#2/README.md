# Integrante #1 — Entregable #2

## Archivos

1. `01_ETL_Integrante1.py` - realiza la carga desde PostgreSQL y MongoDB hacia SQL Server.
2. `02_SQL_Server_Mongo.sql` - crea la tabla necesaria para guardar los eventos GPS de MongoDB.
3. `03_Validacion_Integrante1.sql` - comprueba que la carga fue correcta.

## Orden de ejecución

### Paso 1
En SQL Server ejecutar:

`02_SQL_Server_Mongo.sql`

### Paso 2
Editar en `01_ETL_Integrante1.py`:

- contraseña de PostgreSQL;
- contraseña de SQL Server;
- nombres de las bases si son diferentes.

### Paso 3
Instalar:

`pip install psycopg2-binary pymongo pyodbc`

### Paso 4
Levantar:
- PostgreSQL;
- MongoDB;
- SQL Server.

### Paso 5
Ejecutar:

`python 01_ETL_Integrante1.py`

### Paso 6
Ejecutar:

`03_Validacion_Integrante1.sql`

### Paso 7
Abrir el PBIX existente y seleccionar **Actualizar** o bien crear uno nuevo.

## Qué demuestra el trabajo

PostgreSQL -> SQL Server  
MongoDB -> SQL Server  
SQL Server -> Power BI

No se modifican las tareas de filegroups, particionamiento, índices ni alta disponibilidad porque pertenecen a los demás integrantes.
