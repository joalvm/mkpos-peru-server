-- =============================================================================
-- indexes/01_organization.sql — Índices de configuración y organización.
-- Reglas generales (aplican a toda la carpeta indexes/):
--   · Toda FK lleva índice (ON DELETE RESTRICT los usa, y los joins también);
--     se omite solo cuando otro índice ya empieza por esa columna (se indica).
--   · ux_ = único · ix_ = no único. Todos con COMMENT.
--   · Los índices implícitos de las PK no se comentan: su propósito es evidente.
-- =============================================================================

CREATE UNIQUE INDEX ux_warehouses__code ON org.warehouses (code);
COMMENT ON INDEX org.ux_warehouses__code IS 'Un código de almacén no se repite (aparece en kardex y reportes).';

CREATE INDEX ix_warehouses__updated_seq ON org.warehouses (updated_seq);
COMMENT ON INDEX org.ix_warehouses__updated_seq IS 'Escaneo por cursor del pull de sync.';

CREATE UNIQUE INDEX ux_branches__code ON org.branches (code);
COMMENT ON INDEX org.ux_branches__code IS 'Un código de sucursal no se repite.';

CREATE INDEX ix_branches__warehouse_id ON org.branches (warehouse_id);
COMMENT ON INDEX org.ix_branches__warehouse_id IS 'Índice de FK: qué sucursales usan un almacén (y bloqueo de desactivación de almacenes en uso).';

CREATE INDEX ix_branches__updated_seq ON org.branches (updated_seq);
COMMENT ON INDEX org.ix_branches__updated_seq IS 'Escaneo por cursor del pull de sync.';
