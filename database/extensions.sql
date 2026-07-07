-- =============================================================================
-- extensions.sql — Extensiones de PostgreSQL requeridas por el sistema.
-- Se ejecuta primero (ver init.sql). PostgreSQL 18: uuidv7() es función core,
-- no requiere extensión.
-- =============================================================================

-- Búsqueda difusa por trigramas: autocompletado de productos por nombre en el
-- POS y el panel de administración (índices GIN con gin_trgm_ops).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

COMMENT ON EXTENSION pg_trgm IS
    'Búsqueda por similitud de texto (trigramas); soporta el autocompletado de productos por nombre.';
