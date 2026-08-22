## Dashboard — Análisis Histórico de Movilidad

### Página 1: Puntualidad
- Atraso promedio por ruta (min): identifica qué rutas acumulan más
  retraso respecto al horario programado.
- % Cumplimiento de horario por unidad: mide qué porcentaje de los
  viajes de cada unidad llegaron a tiempo, esto con un margen de 5 min.

### Página 2: Demanda y Recorridos
- Viajes por año y viajes por periodo de partición: muestra el
  volumen de viajes históricos, alineado con el particionamiento
  implementado en el SQL Server (2025 / 2026-S1 / 2026-S2).
- Demanda por día de la semana: identifica qué días concentran
  mayor cantidad de viajes.
- Kilómetros recorridos por ruta: mide el volumen total de
  distancia cubierta por cada ruta.

Datos: generados como conjunto de prueba, fueron 10,000 viajes, sobre el
modelo estrella de SQL Server, mientras se completa la carga real por medio del ETL desde PostgreSQL y MongoDB.

## Validación de Dashboard 

- Datos verificados: atraso promedio (9.5-10.5 min) y cumplimiento
  (25%-40%) consistentes con el conjunto de prueba generado.
- Sin errores de carga en ninguno de los 6 gráficos visuales.
- Interacción cruzada entre los gráficos visuales, si funciona.
- Actualización de datos con conexión en vivo: queda pendiente,
  esto se llegará a validar junto con la entrega del ETL, esto cuando hayan datos 
  reales de PostgreSQL y MongoDB cargados en SQL Server.