# database/ — Esquema completo de la BD central (PostgreSQL 18)

Fuente de verdad del esquema. **Sin migraciones hasta producción**
(PROYECTO.md § 6): cambiar el esquema = editar estos archivos y reconstruir
la BD desde cero. Los seeders reponen los datos.

## Estructura y orden de ejecución

`init.sql` orquesta todo con `\ir` (rutas relativas al propio archivo):

| Orden | Archivo | Contenido |
|---|---|---|
| 1 | `extensions.sql` | `pg_trgm` (uuidv7 es core en PG 18) |
| 2 | `sequences.sql` | `sync_seq` — reloj lógico del pull de sync |
| 3 | `enums/*.sql` | Un archivo por enum; **valores en español** |
| 4 | `tables.sql` | Todas las tablas + COMMENT; **las FK van al final del archivo** (sección RELACIONES), nunca inline |
| 5 | `functions.sql` | Trigger functions (`set_updated_at`, `set_updated_seq`) |
| 6 | `triggers.sql` | Triggers de infraestructura (nunca lógica de negocio) |
| 7 | `views.sql` | `stock_levels` (stock derivado del ledger) |
| 8 | `indexes.sql` | Únicos (`ux_`), FK e índices de consulta (`ix_`) |
| — | `seeds/system.sql` | Roles, permisos, otorgamientos (idempotente, corre siempre) |
| — | `seeds/dev.sql` | Datos de prueba (pendiente; ver PLAN.md T3) |

## Uso

```sh
# construir desde cero (BD vacía)
psql "$DATABASE_URL" -f database/init.sql
psql "$DATABASE_URL" -f database/seeds/system.sql

# cuando exista el Taskfile (PLAN.md): task db:reset / task db:seed:dev
```

## Convenciones (resumen de PROYECTO.md § 6-7)

- PK `uuid DEFAULT uuidv7()`; las filas nacidas en el POS traen su id de la terminal.
- Dinero `bigint` `*_cents`; cantidades `numeric(10,3)`; fechas `timestamptz`.
- Identificadores en inglés; **valores de enums en español** (mayúsculas ASCII).
- Todo objeto que acepte `COMMENT` va comentado en español.
- FKs siempre `ON DELETE RESTRICT` (excepción documentada: `refresh_tokens.replaced_by_id` → `SET NULL`) y siempre indexadas.
- Tablas-libro (`stock_movements`, `payments`, `cash_movements`, …) son
  inmutables: corregir = crear el movimiento contrario o un AJUSTE.
- Stock y dinero **nunca** se guardan como saldos editables: se derivan de eventos.
