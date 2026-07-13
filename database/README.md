# database/ — Esquema completo de la BD central (PostgreSQL 18)

Fuente de verdad del esquema. **Sin migraciones hasta producción**
(PROYECTO.md § 6): cambiar el esquema = editar estos archivos y reconstruir
la BD desde cero. Los seeders reponen los datos.

## Esquemas por dominio

Cada dominio vive en su **propio esquema de PostgreSQL**; `public` queda solo
para extensiones y funciones de infraestructura transversal
(`public.set_updated_at` / `public.set_updated_seq`) — **cero tablas en
public**. Toda referencia SQL (DDL, queries de sqlc, seeds) va **siempre
calificada** `esquema.tabla`: nada depende del `search_path`.

| # | Esquema | Contenido |
|---|---|---|
| 01 | `org` | `business_settings` (singleton), `warehouses`, `branches` |
| 02 | `access` | `users`, `roles`, `permissions`, `role_permissions`, `user_roles`, `refresh_tokens` |
| 03 | `terminals` | `terminals`, `terminal_enrollment_codes`, `terminal_credentials` |
| 04 | `catalog` | `product_categories`, `brands`, `products`, `product_presentations`, `product_barcodes` |
| 05 | `customers` | `customers` |
| 06 | `sales` | `sales`, `sale_items`, `payments`, `sale_documents` |
| 07 | `inventory` | `stock_movements` (kardex), `inventory_counts`, `inventory_count_items`, vista `stock_levels` |
| 08 | `cash` | `cash_sessions`, `cash_movements` |
| 09 | `purchases` | `suppliers`, `purchases`, `purchase_items` |
| 10 | `sync` | `sync_ingest_log`, secuencia `sync_seq` |
| 11 | `reports` | `reports` (estado + cola SKIP LOCKED de reportes en segundo plano) |
| 12 | `notifications` | `notifications` (campanita web/mobile; no sincroniza al POS) |
| 13 | `logs` | telemetría HTTP `requests` + satélites 1:1 (`request_queries/bodies/headers/agents/errors`, `responses`) |

Los enums viven en el esquema de su dominio (`catalog.unit_type`,
`sales.payment_method`, `inventory.movement_type`…).

## Estructura y orden de ejecución

`init.sql` orquesta todo con `\ir` (rutas relativas al propio archivo).
`tables/`, `triggers/` e `indexes/` van **particionados por dominio** — un
archivo por dominio, misma numeración en las tres carpetas — para que ningún
archivo crezca hasta volverse ilegible:

| Orden | Archivo/carpeta | Contenido |
|---|---|---|
| 1 | `schemas.sql` | Los 13 esquemas de dominio, con COMMENT |
| 2 | `extensions.sql` | `pg_trgm` (uuidv7 es core en PG 18) |
| 3 | `sequences.sql` | `sync.sync_seq` — reloj lógico del pull de sync |
| 4 | `enums/*.sql` | Un archivo por enum; **valores en español** |
| 5 | `tables/01..13_*.sql` | Tablas por dominio + COMMENT; **sin FK** |
| 6 | `tables/99_relations.sql` | **TODAS las FK** del esquema (convención: relaciones al final, panorama de corrido; el orden de creación entre dominios deja de importar). `logs` sin FK a propósito |
| 7 | `functions.sql` | Trigger functions (`public.set_updated_at`, `public.set_updated_seq`) + gestión de particiones (`logs.ensure_partitions`, `logs.drop_partitions_older_than`) |
| 8 | `triggers/01..12_*.sql` | Triggers de infraestructura por dominio (nunca lógica de negocio) |
| 9 | `views.sql` | `inventory.stock_levels` (stock derivado del ledger) |
| 10 | `indexes/01..13_*.sql` | Únicos (`ux_`), FK e índices de consulta (`ix_`) por dominio |
| 11 | `SELECT logs.ensure_partitions(1)` | Particiones mensuales iniciales de la telemetría |
| — | `seeds/system.sql` | Roles, permisos, otorgamientos + `business_settings` inicial (idempotente, corre siempre) |
| — | `seeds/dev.sql` | Datos de prueba (pendiente; ver PLAN.md T3) |

## Uso

```sh
# construir desde cero (BD vacía)
psql "$DATABASE_URL" -f database/init.sql
psql "$DATABASE_URL" -f database/seeds/system.sql

# cuando exista el Taskfile (PLAN.md): task db:reset / task db:seed:dev
# (db:reset dropea los 13 esquemas de dominio + public y reconstruye)
```

## Convenciones (resumen de PROYECTO.md § 6-7)

- PK `uuid DEFAULT uuidv7()`; las filas nacidas en el POS traen su id de la
  terminal. Excepción única: `business_settings` (singleton, PK boolean).
- Dinero `bigint` `*_cents`; cantidades `numeric(10,3)`; fechas `timestamptz`
  (+ `occurred_at`/`sold_at` = momento real según el origen offline).
- Organización: **toda sucursal exige un almacén** (`branches.warehouse_id
  NOT NULL`); varias sucursales pueden compartir uno. El stock cuelga siempre
  de almacenes; un almacén sin sucursal que lo apunte = futuro almacén central.
- Catálogo en 3 capas: `products` (concepto + unidad base de stock) →
  `product_presentations` (cómo se vende/compra: factor y precio) →
  `product_barcodes` (N códigos por presentación). El kardex va SIEMPRE en
  unidad base (vender un six-pack mueve −6).
- Impuestos: precios finales con IGV **contenido**; ICBPER por bolsa se suma
  aparte; snapshots fiscales en `sale_items` — todo en 0 mientras
  `business_settings.is_formalized = false`.
- Identificadores en inglés; **valores de enums en español** (mayúsculas ASCII).
- Todo objeto que acepte `COMMENT` va comentado en español (esquemas
  incluidos). Las particiones mensuales de `logs` son instancias generadas
  dinámicamente: no llevan COMMENT propio.
- FKs siempre `ON DELETE RESTRICT` (excepción documentada:
  `refresh_tokens.replaced_by_id` → `SET NULL`) y siempre indexadas. El
  dominio `logs` no lleva FK a propósito (particiones + alta escritura).
- Tablas-libro (`stock_movements`, `payments`, `cash_movements`, …) son
  inmutables: corregir = crear el movimiento contrario, un AJUSTE o un conteo
  físico (`inventory_counts`) que lo genere.
- Stock y dinero **nunca** se guardan como saldos editables: se derivan de eventos.
- `logs`: particionado mensual por `created_at` (PK incluye la clave de
  partición), retención = `DROP` de partición vía
  `logs.drop_partitions_older_than(n)`, escritura asíncrona desde el server y
  redacción previa (headers sensibles fuera; bodies de `/auth/*` y
  `/terminals/enrollment` jamás). Backups críticos pueden excluirlo:
  `pg_dump --exclude-schema=logs`.
