-- =============================================================================
-- tax_affectation — Afectación tributaria (IGV) de un producto.
-- Clasificación SUNAT simplificada: GRAVADO (paga IGV), EXONERADO (Apéndice I:
-- frutas/verduras frescas y similares), INAFECTO (fuera del ámbito del IGV).
-- Mientras el negocio sea informal no se calcula impuesto alguno, pero cada
-- producto ya nace clasificado: al formalizarse (PSE, F3) solo se activa el
-- cálculo — no hay que reclasificar el catálogo entero.
-- =============================================================================

CREATE TYPE tax_affectation AS ENUM (
    'GRAVADO',
    'EXONERADO',
    'INAFECTO'
);

COMMENT ON TYPE tax_affectation IS
    'Afectación IGV de un producto: GRAVADO (18 % contenido en el precio), EXONERADO (Apéndice I, tasa 0) o INAFECTO. Los precios de venta son finales: el IGV va contenido, nunca se suma encima.';
