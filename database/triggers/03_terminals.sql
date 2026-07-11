-- =============================================================================
-- triggers/03_terminals.sql — Triggers de terminales.
-- =============================================================================

CREATE TRIGGER trg_terminals__set_updated_at
    BEFORE UPDATE ON terminals
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_terminals__set_updated_at ON terminals IS
    'Mantiene terminals.updated_at en cada modificación.';
