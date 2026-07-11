-- =============================================================================
-- triggers/03_terminals.sql — Triggers de terminales.
-- =============================================================================

CREATE TRIGGER trg_terminals__set_updated_at
    BEFORE UPDATE ON terminals.terminals
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_terminals__set_updated_at ON terminals.terminals IS
    'Mantiene terminals.updated_at en cada modificación.';
