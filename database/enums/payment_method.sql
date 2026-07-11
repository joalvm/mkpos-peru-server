-- Método de pago aceptado en el POS. El negocio no fía: toda venta se paga en
-- el momento; se permite pago dividido (varias filas en payments por venta).
CREATE TYPE sales.payment_method AS ENUM (
    'EFECTIVO', -- dinero en caja; afecta el arqueo de la sesión de caja
    'YAPE',     -- billetera digital Yape (registro manual del nº de operación)
    'PLIN'      -- billetera digital Plin (registro manual del nº de operación)
);

COMMENT ON TYPE sales.payment_method IS
    'Método de pago de una venta; solo EFECTIVO afecta el efectivo esperado del arqueo de caja.';
