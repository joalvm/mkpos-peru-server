-- =============================================================================
-- init.sql — Orquestador: construye la base de datos completa desde cero.
--
-- Uso (sobre una BD vacía; \ir resuelve rutas relativas a ESTE archivo):
--   psql "$DATABASE_URL" -f database/init.sql
--   psql "$DATABASE_URL" -f database/seeds/system.sql
--
-- Sin migraciones hasta producción (PROYECTO.md § 6): cambiar el esquema =
-- editar estos archivos y reconstruir (task db:reset).
--
-- tables/, indexes/ y triggers/ van particionados POR DOMINIO (un archivo por
-- dominio, misma numeración en las tres carpetas). Las FK de todos los
-- dominios viven juntas en tables/99_relations.sql: así el orden de creación
-- de tablas no importa y el panorama de relaciones se lee de corrido.
-- =============================================================================

\set ON_ERROR_STOP on

-- 1. Extensiones
\ir extensions.sql

-- 2. Secuencias (sync_seq: la usan los DEFAULT de tables/)
\ir sequences.sql

-- 3. Enums (un archivo por tipo)
\ir enums/unit_type.sql
\ir enums/tax_affectation.sql
\ir enums/payment_method.sql
\ir enums/movement_type.sql
\ir enums/inventory_count_status.sql
\ir enums/sale_status.sql
\ir enums/document_type.sql
\ir enums/customer_doc_type.sql
\ir enums/purchase_kind.sql
\ir enums/purchase_status.sql
\ir enums/terminal_status.sql
\ir enums/cash_movement_type.sql

-- 4. Tablas por dominio (sin FK; las relaciones van al final)
\ir tables/01_organization.sql
\ir tables/02_access.sql
\ir tables/03_terminals.sql
\ir tables/04_catalog.sql
\ir tables/05_customers.sql
\ir tables/06_sales.sql
\ir tables/07_inventory.sql
\ir tables/08_cash.sql
\ir tables/09_purchases.sql
\ir tables/10_sync.sql

-- 5. Relaciones (TODAS las FK del esquema)
\ir tables/99_relations.sql

-- 6. Funciones de infraestructura
\ir functions.sql

-- 7. Triggers por dominio
\ir triggers/01_organization.sql
\ir triggers/02_access.sql
\ir triggers/03_terminals.sql
\ir triggers/04_catalog.sql
\ir triggers/05_customers.sql
\ir triggers/06_sales.sql
\ir triggers/07_inventory.sql
\ir triggers/08_cash.sql
\ir triggers/09_purchases.sql

-- 8. Vistas
\ir views.sql

-- 9. Índices por dominio
\ir indexes/01_organization.sql
\ir indexes/02_access.sql
\ir indexes/03_terminals.sql
\ir indexes/04_catalog.sql
\ir indexes/05_customers.sql
\ir indexes/06_sales.sql
\ir indexes/07_inventory.sql
\ir indexes/08_cash.sql
\ir indexes/09_purchases.sql
\ir indexes/10_sync.sql
