# database/ — Esquema completo de la BD central (PostgreSQL 18)

Fuente de verdad del esquema. **Sin migraciones hasta producción**
(PROYECTO.md § 6): cambiar el esquema = editar estos archivos y reconstruir
la BD desde cero. Los seeders reponen los datos.

## Estructura y orden de ejecución

`init.sql` orquesta todo con `\ir` (rutas relativas al propio archivo).
`tables/`, `triggers/` e `indexes/` van **particionados por dominio** — un
archivo por dominio, misma numeración en las tres carpetas — para que ningún
archivo crezca hasta volverse ilegible:

| Orden | Archivo/carpeta | Contenido |
|---|---|---|
| 1 | `extensions.sql` | `pg_trgm` (uuidv7 es core en PG 18) |
| 2 | `sequences.sql` | `sync_seq` — reloj lógico del pull de sync |
| 3 | `enums/*.sql` | Un archivo por enum; **valores en español** |
| 4 | `tables/01..10_*.sql` | Tablas por dominio + COMMENT; **sin FK** |
| 5 | `tables/99_relations.sql` | **TODAS las FK** del esquema (convención: relaciones al final, panorama de corrido; el orden de creación entre dominios deja de importar) |
| 6 | `functions.sql` | Trigger functions (`set_updated_at`, `set_updated_seq`) |
| 7 | `triggers/01..09_*.sql` | Triggers de infraestructura por dominio (nunca lógica de negocio) |
| 8 | `views.sql` | `stock_levels` (stock derivado del ledger) |
| 9 | `indexes/01..10_*.sql` | Únicos (`ux_`), FK e índices de consulta (`ix_`) por dominio |
| — | `seeds/system.sql` | Roles, permisos, otorgamientos + `business_settings` inicial (idempotente, corre siempre) |
| — | `seeds/dev.sql` | Datos de prueba (pendiente; ver PLAN.md T3) |

Dominios (numeración compartida): 01 organización · 02 acceso · 03 terminales ·
04 catálogo · 05 clientes · 06 ventas · 07 inventario · 08 caja · 09 compras ·
10 sync.

## Uso

```sh
# construir desde cero (BD vacía)
psql "$DATABASE_URL" -f database/init.sql
psql "$DATABASE_URL" -f database/seeds/system.sql

# cuando exista el Taskfile (PLAN.md): task db:reset / task db:seed:dev
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
- Todo objeto que acepte `COMMENT` va comentado en español.
- FKs siempre `ON DELETE RESTRICT` (excepción documentada: `refresh_tokens.replaced_by_id` → `SET NULL`) y siempre indexadas.
- Tablas-libro (`stock_movements`, `payments`, `cash_movements`, …) son
  inmutables: corregir = crear el movimiento contrario, un AJUSTE o un conteo
  físico (`inventory_counts`) que lo genere.
- Stock y dinero **nunca** se guardan como saldos editables: se derivan de eventos.
