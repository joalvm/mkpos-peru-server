-- Tipo de comprobante emitido por una venta. Mientras el negocio sea informal
-- ante SUNAT solo se emite NOTA_VENTA; BOLETA y FACTURA se activan al
-- formalizarse (integración PSE, fase F3).
CREATE TYPE document_type AS ENUM (
    'NOTA_VENTA',   -- comprobante interno sin valor tributario (único en uso hoy)
    'BOLETA',       -- boleta electrónica SUNAT (futuro, vía PSE)
    'FACTURA'       -- factura electrónica SUNAT (futuro, vía PSE; exige cliente con RUC)
);

COMMENT ON TYPE document_type IS
    'Tipo de comprobante de una venta; hoy solo NOTA_VENTA (negocio informal), BOLETA/FACTURA quedan definidos para la formalización.';
