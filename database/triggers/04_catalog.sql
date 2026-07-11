-- =============================================================================
-- triggers/04_catalog.sql — Triggers del catálogo (todo el catálogo baja al POS
-- por pull incremental: cada tabla lleva updated_at + updated_seq).
-- =============================================================================

CREATE TRIGGER trg_product_categories__set_updated_at
    BEFORE UPDATE ON catalog.product_categories
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_product_categories__set_updated_at ON catalog.product_categories IS
    'Mantiene product_categories.updated_at en cada modificación.';

CREATE TRIGGER trg_product_categories__set_updated_seq
    BEFORE UPDATE ON catalog.product_categories
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_seq();
COMMENT ON TRIGGER trg_product_categories__set_updated_seq ON catalog.product_categories IS
    'Avanza product_categories.updated_seq para el pull incremental del POS.';

CREATE TRIGGER trg_brands__set_updated_at
    BEFORE UPDATE ON catalog.brands
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_brands__set_updated_at ON catalog.brands IS
    'Mantiene brands.updated_at en cada modificación.';

CREATE TRIGGER trg_brands__set_updated_seq
    BEFORE UPDATE ON catalog.brands
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_seq();
COMMENT ON TRIGGER trg_brands__set_updated_seq ON catalog.brands IS
    'Avanza brands.updated_seq para el pull incremental del POS.';

CREATE TRIGGER trg_products__set_updated_at
    BEFORE UPDATE ON catalog.products
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_products__set_updated_at ON catalog.products IS
    'Mantiene products.updated_at en cada modificación.';

CREATE TRIGGER trg_products__set_updated_seq
    BEFORE UPDATE ON catalog.products
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_seq();
COMMENT ON TRIGGER trg_products__set_updated_seq ON catalog.products IS
    'Avanza products.updated_seq; los cambios de catálogo llegan a las terminales en el siguiente pull.';

CREATE TRIGGER trg_product_presentations__set_updated_at
    BEFORE UPDATE ON catalog.product_presentations
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_product_presentations__set_updated_at ON catalog.product_presentations IS
    'Mantiene product_presentations.updated_at en cada modificación.';

CREATE TRIGGER trg_product_presentations__set_updated_seq
    BEFORE UPDATE ON catalog.product_presentations
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_seq();
COMMENT ON TRIGGER trg_product_presentations__set_updated_seq ON catalog.product_presentations IS
    'Avanza product_presentations.updated_seq; así los cambios de PRECIO llegan a las terminales en el siguiente pull.';

CREATE TRIGGER trg_product_barcodes__set_updated_at
    BEFORE UPDATE ON catalog.product_barcodes
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_product_barcodes__set_updated_at ON catalog.product_barcodes IS
    'Mantiene product_barcodes.updated_at en cada modificación.';

CREATE TRIGGER trg_product_barcodes__set_updated_seq
    BEFORE UPDATE ON catalog.product_barcodes
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_seq();
COMMENT ON TRIGGER trg_product_barcodes__set_updated_seq ON catalog.product_barcodes IS
    'Avanza product_barcodes.updated_seq; altas y bajas de códigos llegan al POS por pull.';
