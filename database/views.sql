-- =============================================================================
-- views.sql — Vistas derivadas.
-- El stock NUNCA se guarda como saldo editable: siempre se deriva del libro
-- mayor stock_movements (regla de oro del proyecto).
-- =============================================================================

-- Stock actual por producto y sucursal. Si el volumen lo exige algún día, se
-- materializa o se cachea; hoy un minimarket no lo necesita.
CREATE VIEW stock_levels AS
SELECT
    sm.branch_id,
    sm.product_id,
    SUM(sm.quantity)::numeric(12,3) AS quantity,
    MAX(sm.created_at)              AS last_movement_at
FROM stock_movements sm
GROUP BY sm.branch_id, sm.product_id;

COMMENT ON VIEW stock_levels IS
    'Stock actual por producto y sucursal, derivado como SUM(quantity) del libro mayor stock_movements; fuente única de verdad del inventario.';
COMMENT ON COLUMN stock_levels.branch_id IS 'Sucursal del saldo.';
COMMENT ON COLUMN stock_levels.product_id IS 'Producto del saldo.';
COMMENT ON COLUMN stock_levels.quantity IS 'Existencia actual en la unidad del producto; puede ser negativa si hubo ventas sin registrar compras (se corrige con AJUSTE).';
COMMENT ON COLUMN stock_levels.last_movement_at IS 'Fecha del último movimiento del producto en esa sucursal.';
