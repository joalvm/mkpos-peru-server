-- =============================================================================
-- indexes/10_sync.sql — Índices de sincronización.
-- =============================================================================

CREATE UNIQUE INDEX ux_sync_ingest_log__event_id ON sync_ingest_log (event_id);
COMMENT ON INDEX ux_sync_ingest_log__event_id IS 'Clave de deduplicación del push idempotente: un evento se aplica una sola vez.';

CREATE INDEX ix_sync_ingest_log__terminal_received
    ON sync_ingest_log (terminal_id, received_at);
COMMENT ON INDEX ix_sync_ingest_log__terminal_received IS 'Auditoría de ingesta por terminal y fecha; cubre además la FK terminal_id.';
