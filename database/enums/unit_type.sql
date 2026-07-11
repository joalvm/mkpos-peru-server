-- Unidad BASE de un producto: la unidad en la que se lleva el stock y se
-- expresan los movimientos del kardex. Cómo se vende o compra (unidad suelta,
-- six-pack, caja x24, docena) NO va aquí: eso son product_presentations con su
-- factor de conversión a esta unidad base.
-- Las unidades fraccionables (KG, G, L, ML, M) habilitan cantidades
-- numeric(10,3) (granel). Valores en español, mayúsculas ASCII. Enum solo aditivo.
CREATE TYPE unit_type AS ENUM (
    'UNIDAD',   -- pieza individual (la docena es una presentación con factor 12)
    'KG',       -- kilogramo (granel pesado en balanza)
    'G',        -- gramo (granel en cantidades pequeñas: especias, etc.)
    'L',        -- litro (líquidos a granel)
    'ML',       -- mililitro (líquidos en cantidades pequeñas)
    'M'         -- metro (cable, cinta, soga)
);

COMMENT ON TYPE unit_type IS
    'Unidad base de stock de un producto; KG/G/L/ML/M permiten cantidades fraccionadas (granel). Las formas de venta/compra (six-pack, caja, docena) son product_presentations con factor sobre esta unidad.';
