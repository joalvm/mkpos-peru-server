-- =============================================================================
-- indexes/04_catalog.sql — Índices del catálogo de productos.
-- =============================================================================

CREATE UNIQUE INDEX ux_product_categories__name ON product_categories (lower(name));
COMMENT ON INDEX ux_product_categories__name IS 'Nombre de categoría único sin distinción de mayúsculas.';

CREATE INDEX ix_product_categories__updated_seq ON product_categories (updated_seq);
COMMENT ON INDEX ix_product_categories__updated_seq IS 'Escaneo por cursor del pull de sync.';

CREATE UNIQUE INDEX ux_brands__name ON brands (lower(name));
COMMENT ON INDEX ux_brands__name IS 'Nombre de marca único sin distinción de mayúsculas (evita "Gloria"/"GLORIA" duplicadas).';

CREATE INDEX ix_brands__updated_seq ON brands (updated_seq);
COMMENT ON INDEX ix_brands__updated_seq IS 'Escaneo por cursor del pull de sync.';

CREATE INDEX ix_products__category_id ON products (category_id);
COMMENT ON INDEX ix_products__category_id IS 'Índice de FK: listado de productos por categoría.';

CREATE INDEX ix_products__brand_id ON products (brand_id) WHERE brand_id IS NOT NULL;
COMMENT ON INDEX ix_products__brand_id IS 'Índice de FK: listado de productos por marca; parcial porque el granel no suele tener.';

CREATE INDEX ix_products__name_trgm ON products USING gin (name gin_trgm_ops);
COMMENT ON INDEX ix_products__name_trgm IS 'Autocompletado por similitud de nombre (pg_trgm) para búsqueda en POS y panel.';

CREATE INDEX ix_products__updated_seq ON products (updated_seq);
COMMENT ON INDEX ix_products__updated_seq IS 'Escaneo por cursor del pull de sync (catálogo y clasificación fiscal).';

CREATE INDEX ix_product_presentations__product_id ON product_presentations (product_id);
COMMENT ON INDEX ix_product_presentations__product_id IS 'Índice de FK: presentaciones de un producto.';

CREATE UNIQUE INDEX ux_product_presentations__name_per_product
    ON product_presentations (product_id, lower(name));
COMMENT ON INDEX ux_product_presentations__name_per_product IS 'Un producto no repite nombre de presentación ("Caja x 24" dos veces sería ambiguo en compras y tickets).';

CREATE UNIQUE INDEX ux_product_presentations__default_sale_per_product
    ON product_presentations (product_id) WHERE is_default_sale;
COMMENT ON INDEX ux_product_presentations__default_sale_per_product IS 'A lo sumo una presentación de venta por defecto por producto (la que usa el POS al buscar por nombre).';

CREATE UNIQUE INDEX ux_product_presentations__default_purchase_per_product
    ON product_presentations (product_id) WHERE is_default_purchase;
COMMENT ON INDEX ux_product_presentations__default_purchase_per_product IS 'A lo sumo una presentación de compra por defecto por producto (preseleccionada al registrar compras).';

CREATE INDEX ix_product_presentations__updated_seq ON product_presentations (updated_seq);
COMMENT ON INDEX ix_product_presentations__updated_seq IS 'Escaneo por cursor del pull de sync (cambios de precio).';

CREATE UNIQUE INDEX ux_product_barcodes__barcode ON product_barcodes (barcode);
COMMENT ON INDEX ux_product_barcodes__barcode IS 'Un código escaneado resuelve a UNA sola presentación; búsqueda exacta del scanner.';

CREATE INDEX ix_product_barcodes__product_presentation_id
    ON product_barcodes (product_presentation_id);
COMMENT ON INDEX ix_product_barcodes__product_presentation_id IS 'Índice de FK: códigos de una presentación.';

CREATE INDEX ix_product_barcodes__updated_seq ON product_barcodes (updated_seq);
COMMENT ON INDEX ix_product_barcodes__updated_seq IS 'Escaneo por cursor del pull de sync.';
