-- =============================================================================
-- triggers/05_customers.sql — Triggers de clientes.
-- =============================================================================

CREATE TRIGGER trg_customers__set_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_customers__set_updated_at ON customers IS
    'Mantiene customers.updated_at en cada modificación.';

CREATE TRIGGER trg_customers__set_updated_seq
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_customers__set_updated_seq ON customers IS
    'Avanza customers.updated_seq para el pull incremental del POS.';
