-- =============================================================================
-- views.sql — Vistas derivadas.
-- El stock NUNCA se guarda como saldo editable: siempre se deriva del libro
-- mayor stock_movements (regla de oro del proyecto).
-- =============================================================================

-- Stock actual por producto y almacén (expone también la sucursal del almacén).
-- El stock de una sucursal = Σ de sus almacenes (v1: exactamente uno).
-- Si el volumen lo exige algún día, se materializa o se cachea; hoy un
-- minimarket no lo necesita.
CREATE VIEW stock_levels AS
SELECT
    w.branch_id,
    sm.warehouse_id,
    sm.product_id,
    SUM(sm.quantity)::numeric(12,3) AS quantity,
    MAX(sm.occurred_at)             AS last_movement_at
FROM stock_movements sm
JOIN warehouses w ON w.id = sm.warehouse_id
GROUP BY w.branch_id, sm.warehouse_id, sm.product_id;

COMMENT ON VIEW stock_levels IS
    'Stock actual por producto y almacén, derivado como SUM(quantity) del libro mayor stock_movements; fuente única de verdad del inventario. branch_id viene del almacén (NULL si algún día existe un almacén central sin tienda).';
COMMENT ON COLUMN stock_levels.branch_id IS 'Sucursal dueña del almacén; NULL para un futuro almacén central.';
COMMENT ON COLUMN stock_levels.warehouse_id IS 'Almacén del saldo.';
COMMENT ON COLUMN stock_levels.product_id IS 'Producto del saldo.';
COMMENT ON COLUMN stock_levels.quantity IS 'Existencia actual en la unidad del producto; puede ser negativa si hubo ventas sin registrar compras (se corrige con AJUSTE).';
COMMENT ON COLUMN stock_levels.last_movement_at IS 'Fecha real (occurred_at) del último movimiento del producto en ese almacén.';
