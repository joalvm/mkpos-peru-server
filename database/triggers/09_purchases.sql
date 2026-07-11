-- =============================================================================
-- triggers/09_purchases.sql — Triggers de proveedores y compras.
-- purchase_items es tabla-libro: sin triggers.
-- =============================================================================

CREATE TRIGGER trg_suppliers__set_updated_at
    BEFORE UPDATE ON purchases.suppliers
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_suppliers__set_updated_at ON purchases.suppliers IS
    'Mantiene suppliers.updated_at en cada modificación.';

CREATE TRIGGER trg_purchases__set_updated_at
    BEFORE UPDATE ON purchases.purchases
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_purchases__set_updated_at ON purchases.purchases IS
    'Mantiene purchases.updated_at (cambia al recibir o cancelar).';
