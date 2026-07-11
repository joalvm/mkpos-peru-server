-- =============================================================================
-- triggers/12_notifications.sql — Triggers de notificaciones.
-- Sin updated_seq: la campanita no se sincroniza al POS.
-- =============================================================================

CREATE TRIGGER trg_notifications__set_updated_at
    BEFORE UPDATE ON notifications.notifications
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_notifications__set_updated_at ON notifications.notifications IS
    'Mantiene notifications.updated_at (cambia al marcarse como leída).';
