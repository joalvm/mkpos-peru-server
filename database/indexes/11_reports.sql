-- =============================================================================
-- indexes/11_reports.sql — Índices de reportes en segundo plano.
-- =============================================================================

CREATE INDEX ix_reports__requested_by_created ON reports.reports (requested_by, created_at);
COMMENT ON INDEX reports.ix_reports__requested_by_created IS 'Índice de FK requested_by + listado "mis reportes" ordenado por fecha.';

CREATE INDEX ix_reports__queue ON reports.reports (created_at) WHERE status = 'PENDIENTE';
COMMENT ON INDEX reports.ix_reports__queue IS 'Cola de trabajo: los workers toman el PENDIENTE más antiguo (FOR UPDATE SKIP LOCKED); parcial para que el escaneo no pague reportes ya resueltos.';
