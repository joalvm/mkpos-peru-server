-- =============================================================================
-- indexes/07_inventory.sql — Índices de inventario (kardex y conteos).
-- =============================================================================

CREATE INDEX ix_stock_movements__warehouse_product
    ON inventory.stock_movements (warehouse_id, product_id, occurred_at);
COMMENT ON INDEX inventory.ix_stock_movements__warehouse_product IS 'Kardex de un producto en un almacén (orden cronológico real) y agregación de stock_levels; cubre además la FK warehouse_id.';

CREATE INDEX ix_stock_movements__product_id ON inventory.stock_movements (product_id);
COMMENT ON INDEX inventory.ix_stock_movements__product_id IS 'Índice de FK: movimientos de un producto en todos los almacenes.';

CREATE INDEX ix_stock_movements__sale_item_id ON inventory.stock_movements (sale_item_id)
    WHERE sale_item_id IS NOT NULL;
COMMENT ON INDEX inventory.ix_stock_movements__sale_item_id IS 'Índice de FK: trazabilidad venta → movimiento; parcial.';

CREATE INDEX ix_stock_movements__purchase_item_id ON inventory.stock_movements (purchase_item_id)
    WHERE purchase_item_id IS NOT NULL;
COMMENT ON INDEX inventory.ix_stock_movements__purchase_item_id IS 'Índice de FK: trazabilidad compra → movimiento; parcial.';

CREATE INDEX ix_stock_movements__inventory_count_item_id ON inventory.stock_movements (inventory_count_item_id)
    WHERE inventory_count_item_id IS NOT NULL;
COMMENT ON INDEX inventory.ix_stock_movements__inventory_count_item_id IS 'Índice de FK: trazabilidad conteo físico → ajuste; parcial.';

CREATE INDEX ix_stock_movements__user_id ON inventory.stock_movements (user_id);
COMMENT ON INDEX inventory.ix_stock_movements__user_id IS 'Índice de FK: auditoría de movimientos por usuario.';

CREATE UNIQUE INDEX ux_inventory_counts__open_per_warehouse
    ON inventory.inventory_counts (warehouse_id) WHERE status = 'EN_CURSO';
COMMENT ON INDEX inventory.ux_inventory_counts__open_per_warehouse IS 'A lo sumo un conteo físico en curso por almacén: dos conteos simultáneos del mismo stock se pisarían.';

CREATE INDEX ix_inventory_counts__warehouse_id ON inventory.inventory_counts (warehouse_id);
COMMENT ON INDEX inventory.ix_inventory_counts__warehouse_id IS 'Índice de FK completo: historial de conteos de un almacén (el único parcial no cubre aplicados/cancelados).';

CREATE INDEX ix_inventory_counts__created_by ON inventory.inventory_counts (created_by);
COMMENT ON INDEX inventory.ix_inventory_counts__created_by IS 'Índice de FK created_by.';

CREATE INDEX ix_inventory_counts__applied_by ON inventory.inventory_counts (applied_by)
    WHERE applied_by IS NOT NULL;
COMMENT ON INDEX inventory.ix_inventory_counts__applied_by IS 'Índice de FK applied_by; parcial.';

CREATE INDEX ix_inventory_counts__cancelled_by ON inventory.inventory_counts (cancelled_by)
    WHERE cancelled_by IS NOT NULL;
COMMENT ON INDEX inventory.ix_inventory_counts__cancelled_by IS 'Índice de FK cancelled_by; parcial.';

CREATE UNIQUE INDEX ux_inventory_count_items__product_per_count
    ON inventory.inventory_count_items (inventory_count_id, product_id);
COMMENT ON INDEX inventory.ux_inventory_count_items__product_per_count IS 'Un producto se cuenta una sola vez por conteo; cubre además la FK inventory_count_id.';

CREATE INDEX ix_inventory_count_items__product_id ON inventory.inventory_count_items (product_id);
COMMENT ON INDEX inventory.ix_inventory_count_items__product_id IS 'Índice de FK: historial de conteos de un producto.';
