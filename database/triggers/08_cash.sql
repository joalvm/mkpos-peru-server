-- =============================================================================
-- triggers/08_cash.sql — Triggers de caja. cash_movements es tabla-libro: sin triggers.
-- =============================================================================

CREATE TRIGGER trg_cash_sessions__set_updated_at
    BEFORE UPDATE ON cash.cash_sessions
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_cash_sessions__set_updated_at ON cash.cash_sessions IS
    'Mantiene cash_sessions.updated_at (cambia al cerrar la sesión).';
