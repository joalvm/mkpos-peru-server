-- Tipo de movimiento de inventario. El stock nunca se edita a mano: es la suma
-- de estos movimientos (ver vista stock_levels); corregir = crear AJUSTE.
CREATE TYPE inventory.movement_type AS ENUM (
    'VENTA',            -- salida por venta (cantidad negativa)
    'ANULACION_VENTA',  -- reingreso por venta anulada (cantidad positiva)
    'COMPRA',           -- ingreso por compra recibida (cantidad positiva)
    'AJUSTE',           -- corrección tras conteo físico (signo libre, exige motivo)
    'MERMA'             -- pérdida: vencido, roto, robado (cantidad negativa, exige motivo)
);

COMMENT ON TYPE inventory.movement_type IS
    'Tipo de movimiento del libro mayor de inventario (stock_movements); el signo de la cantidad está restringido por CHECK según el tipo.';
