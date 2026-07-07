-- Unidad de medida en la que se vende un producto. Las unidades fraccionables
-- (KG, G, L, ML, M) habilitan la venta a granel con cantidad numeric(10,3).
-- Valores en español, mayúsculas ASCII (regla del proyecto). Enum solo aditivo.
CREATE TYPE unit_type AS ENUM (
    'UNIDAD',   -- pieza individual
    'DOCENA',   -- grupo de 12 unidades (p. ej. huevos)
    'KG',       -- kilogramo (granel pesado en balanza)
    'G',        -- gramo (granel en cantidades pequeñas: especias, etc.)
    'L',        -- litro (líquidos a granel)
    'ML',       -- mililitro (líquidos en cantidades pequeñas)
    'M'         -- metro (cable, cinta, soga)
);

COMMENT ON TYPE unit_type IS
    'Unidad de medida de venta de un producto; KG/G/L/ML/M permiten cantidades fraccionadas (granel).';
