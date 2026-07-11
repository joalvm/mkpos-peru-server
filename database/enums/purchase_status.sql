-- Estado del ciclo de vida de una compra. Recibir la compra es lo que genera
-- los movimientos de stock COMPRA (nunca antes).
CREATE TYPE purchases.purchase_status AS ENUM (
    'PEDIDA',       -- pedido hecho a la distribuidora, mercadería aún no llega
    'RECIBIDA',     -- mercadería recibida y verificada; stock ya ingresado
    'CANCELADA'     -- pedido cancelado antes de recibirse; no toca stock
);

COMMENT ON TYPE purchases.purchase_status IS
    'Estado de una compra; solo el paso a RECIBIDA genera movimientos de stock COMPRA.';
