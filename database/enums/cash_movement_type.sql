-- Tipo de movimiento manual de efectivo dentro de una sesión de caja
-- (las ventas en efectivo NO van aquí: entran al arqueo vía payments).
CREATE TYPE cash_movement_type AS ENUM (
    'INGRESO',  -- entra efectivo: sencillo/cambio inicial extra, aporte de la dueña
    'RETIRO'    -- sale efectivo: pago a proveedor desde caja, retiro de la dueña, gasto menor
);

COMMENT ON TYPE cash_movement_type IS
    'Movimiento manual de efectivo en una sesión de caja; participa en la fórmula del arqueo (esperado = apertura + ventas EFECTIVO + INGRESO − RETIRO).';
