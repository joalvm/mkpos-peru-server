-- =============================================================================
-- triggers/07_inventory.sql — Triggers de inventario. stock_movements e
-- inventory_count_items son tablas-libro (inmutables): sin triggers.
-- =============================================================================

CREATE TRIGGER trg_inventory_counts__set_updated_at
    BEFORE UPDATE ON inventory.inventory_counts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_inventory_counts__set_updated_at ON inventory.inventory_counts IS
    'Mantiene inventory_counts.updated_at (cambia al aplicar o cancelar el conteo).';
