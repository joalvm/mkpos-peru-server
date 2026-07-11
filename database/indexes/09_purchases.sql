-- =============================================================================
-- indexes/09_purchases.sql — Índices de proveedores y compras.
-- =============================================================================

CREATE UNIQUE INDEX ux_suppliers__ruc ON suppliers (ruc) WHERE ruc IS NOT NULL;
COMMENT ON INDEX ux_suppliers__ruc IS 'RUC único cuando existe; parcial porque los puestos del mayorista pueden no tener.';

CREATE INDEX ix_purchases__warehouse_id ON purchases (warehouse_id);
COMMENT ON INDEX ix_purchases__warehouse_id IS 'Índice de FK: compras por almacén.';

CREATE INDEX ix_purchases__supplier_id ON purchases (supplier_id) WHERE supplier_id IS NOT NULL;
COMMENT ON INDEX ix_purchases__supplier_id IS 'Índice de FK: historial por proveedor; parcial.';

CREATE INDEX ix_purchases__created_by ON purchases (created_by);
COMMENT ON INDEX ix_purchases__created_by IS 'Índice de FK created_by.';

CREATE INDEX ix_purchase_items__purchase_id ON purchase_items (purchase_id);
COMMENT ON INDEX ix_purchase_items__purchase_id IS 'Índice de FK: líneas de una compra.';

CREATE INDEX ix_purchase_items__product_id ON purchase_items (product_id);
COMMENT ON INDEX ix_purchase_items__product_id IS 'Índice de FK: historial de costos de un producto.';

CREATE INDEX ix_purchase_items__product_presentation_id ON purchase_items (product_presentation_id);
COMMENT ON INDEX ix_purchase_items__product_presentation_id IS 'Índice de FK: compras por presentación (a qué formato conviene comprar).';
