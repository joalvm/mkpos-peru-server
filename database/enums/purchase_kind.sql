-- Modalidad de compra de mercadería, según cómo compra el negocio en Piura.
CREATE TYPE purchase_kind AS ENUM (
    'MAYORISTA',        -- compra directa en mercado mayorista: se paga y recibe en el acto (nace RECIBIDA, proveedor opcional)
    'DISTRIBUIDORA'     -- pedido a distribuidora (Alvarez Bohl, Kompass): se pide y llega días después (nace PEDIDA, proveedor obligatorio)
);

COMMENT ON TYPE purchase_kind IS
    'Modalidad de compra: MAYORISTA es inmediata (nace RECIBIDA), DISTRIBUIDORA es pedido con entrega posterior (PEDIDA → RECIBIDA | CANCELADA).';
