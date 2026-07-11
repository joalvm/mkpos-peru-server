-- =============================================================================
-- indexes/06_sales.sql — Índices de ventas.
-- =============================================================================

CREATE UNIQUE INDEX ux_sales__terminal_local_number ON sales (terminal_id, local_number);
COMMENT ON INDEX ux_sales__terminal_local_number IS 'El correlativo local no se repite dentro de una terminal; cubre además la FK terminal_id.';

CREATE INDEX ix_sales__branch_sold_on ON sales (branch_id, sold_on_local);
COMMENT ON INDEX ix_sales__branch_sold_on IS 'Reportes y cierres diarios por sucursal y fecha de negocio; cubre además la FK branch_id.';

CREATE INDEX ix_sales__cash_session_id ON sales (cash_session_id);
COMMENT ON INDEX ix_sales__cash_session_id IS 'Índice de FK: ventas de una sesión de caja (cálculo del arqueo).';

CREATE INDEX ix_sales__user_id ON sales (user_id);
COMMENT ON INDEX ix_sales__user_id IS 'Índice de FK: ventas por cajero.';

CREATE INDEX ix_sales__customer_id ON sales (customer_id) WHERE customer_id IS NOT NULL;
COMMENT ON INDEX ix_sales__customer_id IS 'Índice de FK: historial de un cliente; parcial porque casi toda venta es anónima.';

CREATE INDEX ix_sales__voided_by ON sales (voided_by) WHERE voided_by IS NOT NULL;
COMMENT ON INDEX ix_sales__voided_by IS 'Índice de FK: auditoría de anulaciones por usuario; parcial.';

CREATE INDEX ix_sale_items__sale_id ON sale_items (sale_id);
COMMENT ON INDEX ix_sale_items__sale_id IS 'Índice de FK: líneas de una venta.';

CREATE INDEX ix_sale_items__product_id ON sale_items (product_id);
COMMENT ON INDEX ix_sale_items__product_id IS 'Índice de FK: historial de ventas de un producto (top productos).';

CREATE INDEX ix_sale_items__product_presentation_id ON sale_items (product_presentation_id);
COMMENT ON INDEX ix_sale_items__product_presentation_id IS 'Índice de FK: ventas por presentación (qué formatos rotan más).';

CREATE INDEX ix_payments__sale_id ON payments (sale_id);
COMMENT ON INDEX ix_payments__sale_id IS 'Índice de FK: pagos de una venta.';

CREATE UNIQUE INDEX ux_sale_documents__sale_id ON sale_documents (sale_id);
COMMENT ON INDEX ux_sale_documents__sale_id IS 'Una venta emite exactamente un comprobante; cubre además la FK sale_id.';

CREATE UNIQUE INDEX ux_sale_documents__doc ON sale_documents (doc_type, series, number);
COMMENT ON INDEX ux_sale_documents__doc IS 'No hay dos comprobantes con el mismo tipo, serie y número.';
