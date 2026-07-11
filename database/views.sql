-- =============================================================================
-- views.sql — Vistas derivadas.
-- El stock NUNCA se guarda como saldo editable: siempre se deriva del libro
-- mayor stock_movements (regla de oro del proyecto).
-- =============================================================================

-- Stock actual por producto y almacén, en unidad base del producto.
-- El stock que "ve" una sucursal es el de su almacén asignado
-- (branches.warehouse_id); sucursales que comparten almacén ven el mismo pool.
-- Si el volumen lo exige algún día, se materializa o se cachea; hoy un
-- minimarket no lo necesita.
CREATE VIEW stock_levels AS
SELECT
    sm.warehouse_id,
    sm.product_id,
    SUM(sm.quantity)::numeric(12,3) AS quantity,
    MAX(sm.occurred_at)             AS last_movement_at
FROM stock_movements sm
GROUP BY sm.warehouse_id, sm.product_id;

COMMENT ON VIEW stock_levels IS
    'Stock actual por producto y almacén, derivado como SUM(quantity) del libro mayor stock_movements; fuente única de verdad del inventario. El stock por sucursal se obtiene uniendo branches.warehouse_id (varias sucursales pueden compartir el mismo almacén y por tanto el mismo saldo).';
COMMENT ON COLUMN stock_levels.warehouse_id IS 'Almacén del saldo.';
COMMENT ON COLUMN stock_levels.product_id IS 'Producto del saldo.';
COMMENT ON COLUMN stock_levels.quantity IS 'Existencia actual en la unidad base del producto; puede ser negativa si hubo ventas sin registrar compras (se corrige con AJUSTE o un conteo físico).';
COMMENT ON COLUMN stock_levels.last_movement_at IS 'Fecha real (occurred_at) del último movimiento del producto en ese almacén.';
