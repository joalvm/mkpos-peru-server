-- =============================================================================
-- triggers/06_sales.sql — Triggers de ventas (solo la cabecera es mutable:
-- cambia únicamente al anular; items/pagos/documentos son tablas-libro).
-- =============================================================================

CREATE TRIGGER trg_sales__set_updated_at
    BEFORE UPDATE ON sales.sales
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_sales__set_updated_at ON sales.sales IS
    'Mantiene sales.updated_at (una venta solo se modifica al anularse).';
