-- =============================================================================
-- indexes/01_organization.sql — Índices de configuración y organización.
-- Reglas generales (aplican a toda la carpeta indexes/):
--   · Toda FK lleva índice (ON DELETE RESTRICT los usa, y los joins también);
--     se omite solo cuando otro índice ya empieza por esa columna (se indica).
--   · ux_ = único · ix_ = no único. Todos con COMMENT.
--   · Los índices implícitos de las PK no se comentan: su propósito es evidente.
-- =============================================================================

CREATE UNIQUE INDEX ux_warehouses__code ON warehouses (code);
COMMENT ON INDEX ux_warehouses__code IS 'Un código de almacén no se repite (aparece en kardex y reportes).';

CREATE INDEX ix_warehouses__updated_seq ON warehouses (updated_seq);
COMMENT ON INDEX ix_warehouses__updated_seq IS 'Escaneo por cursor del pull de sync.';

CREATE UNIQUE INDEX ux_branches__code ON branches (code);
COMMENT ON INDEX ux_branches__code IS 'Un código de sucursal no se repite.';

CREATE INDEX ix_branches__warehouse_id ON branches (warehouse_id);
COMMENT ON INDEX ix_branches__warehouse_id IS 'Índice de FK: qué sucursales usan un almacén (y bloqueo de desactivación de almacenes en uso).';

CREATE INDEX ix_branches__updated_seq ON branches (updated_seq);
COMMENT ON INDEX ix_branches__updated_seq IS 'Escaneo por cursor del pull de sync.';
