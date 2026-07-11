-- Estado de una venta. Las ventas nunca se borran ni se editan: anular crea
-- movimientos ANULACION_VENTA y marca la venta como ANULADA.
CREATE TYPE sales.sale_status AS ENUM (
    'COMPLETADA',   -- venta registrada y cobrada
    'ANULADA'       -- venta anulada (conserva quién, cuándo y por qué)
);

COMMENT ON TYPE sales.sale_status IS
    'Estado de una venta; ANULADA conserva el registro histórico y revierte stock vía movimientos ANULACION_VENTA.';
