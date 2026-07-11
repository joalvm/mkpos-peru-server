-- =============================================================================
-- triggers/11_reports.sql — Triggers de reportes en segundo plano.
-- Sin updated_seq: los reportes no se sincronizan al POS.
-- =============================================================================

CREATE TRIGGER trg_reports__set_updated_at
    BEFORE UPDATE ON reports.reports
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
COMMENT ON TRIGGER trg_reports__set_updated_at ON reports.reports IS
    'Mantiene reports.updated_at (cambia con cada transición de la cola: tomar, completar, fallar).';
