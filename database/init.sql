-- =============================================================================
-- init.sql — Orquestador: construye la base de datos completa desde cero.
--
-- Uso (sobre una BD vacía; \ir resuelve rutas relativas a ESTE archivo):
--   psql "$DATABASE_URL" -f database/init.sql
--   psql "$DATABASE_URL" -f database/seeds/system.sql
--
-- Sin migraciones hasta producción (PROYECTO.md § 6): cambiar el esquema =
-- editar estos archivos y reconstruir (task db:reset).
-- =============================================================================

\set ON_ERROR_STOP on

-- 1. Extensiones
\ir extensions.sql

-- 2. Secuencias (sync_seq: la usan los DEFAULT de tables.sql)
\ir sequences.sql

-- 3. Enums (un archivo por tipo)
\ir enums/unit_type.sql
\ir enums/tax_affectation.sql
\ir enums/payment_method.sql
\ir enums/movement_type.sql
\ir enums/sale_status.sql
\ir enums/document_type.sql
\ir enums/customer_doc_type.sql
\ir enums/purchase_kind.sql
\ir enums/purchase_status.sql
\ir enums/terminal_status.sql
\ir enums/cash_movement_type.sql

-- 4. Tablas (definiciones + relaciones al final del archivo)
\ir tables.sql

-- 5. Funciones de infraestructura
\ir functions.sql

-- 6. Triggers
\ir triggers.sql

-- 7. Vistas
\ir views.sql

-- 8. Índices
\ir indexes.sql
