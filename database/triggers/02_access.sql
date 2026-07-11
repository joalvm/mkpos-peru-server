-- =============================================================================
-- triggers/02_access.sql — Triggers de identidad y acceso.
-- =============================================================================

CREATE TRIGGER trg_users__set_updated_at
    BEFORE UPDATE ON access.users
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_users__set_updated_at ON access.users IS
    'Mantiene users.updated_at en cada modificación.';

CREATE TRIGGER trg_users__set_updated_seq
    BEFORE UPDATE ON access.users
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_seq();
COMMENT ON TRIGGER trg_users__set_updated_seq ON access.users IS
    'Avanza users.updated_seq; crítico para que cambios de PIN y bajas de personal lleguen al POS.';

CREATE TRIGGER trg_roles__set_updated_at
    BEFORE UPDATE ON access.roles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_roles__set_updated_at ON access.roles IS
    'Mantiene roles.updated_at en cada modificación.';
