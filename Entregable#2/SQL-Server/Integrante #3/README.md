# Alta Disponibilidad SQL Server

## ¿Qué se hizo?

Se configuraron **dos servidores Ubuntu con SQL Server** para trabajar con **Always On Availability Groups**:

* 🟢 **Maestro:**  — servidor principal.
* 🔵 **Esclavo:**  — servidor secundario.

Ambos servidores mantienen una copia de la base de datos **`HA_Test`** mediante el grupo de disponibilidad **`HA_Test_AG`**.

## ¿Cómo funciona?

Los cambios realizados en el **maestro** se sincronizan con el **esclavo** mediante el puerto **5022**.

```text
        MAESTRO
    IP PRIVADA
          │
          │ Puerto 5022
          ▼
        ESCLAVO
    IP PRIVADA
```

Si el maestro falla, el esclavo puede convertirse en el servidor principal mediante un **failover manual**, permitiendo continuar trabajando con la base de datos.

## Comprobación

Para verificar que SQL Server está funcionando:

```bash
sudo systemctl status mssql-server
```

Y para comprobar Always On:

```sql
SELECT SERVERPROPERTY('IsHadrEnabled');
```

Si devuelve **`1`**, Always On está habilitado.

### En resumen

**Dos servidores → una base de datos sincronizada → mayor disponibilidad → posibilidad de cambiar al servidor secundario si el principal falla.**


                    ┌─────────────────────┐
                    │      PACEMAKER      │
                    │      COROSYNC       │
                    └──────────┬──────────┘
                               │
                 controla el recurso SQL AG
                               │
              ┌────────────────┴────────────────┐
              │                                 │
       ┌──────▼──────┐                   ┌──────▼──────┐
       │   MAESTRO   │                   │   ESCLAVO   │
       │             │                   │             │
       │  SQL Server │◄══ TCP 5022 ═══►  │  SQL Server │
       │ ip privada  │                   │ ip privada  │
       │             │                   │             │
       │ PRIMARY     │                   │ SECONDARY   │
       └─────────────┘                   └─────────────┘
