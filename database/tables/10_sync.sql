-- =============================================================================
-- tables/10_sync.sql — Infraestructura de sincronización.
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE sync_ingest_log (
    id          uuid        NOT NULL DEFAULT uuidv7(),
    terminal_id uuid        NOT NULL,
    event_id    uuid        NOT NULL,
    event_type  text        NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_sync_ingest_log PRIMARY KEY (id)
);

COMMENT ON TABLE sync_ingest_log IS
    'Registro de eventos recibidos por sync push; garantiza idempotencia. La terminal reenvía hasta recibir confirmación: si el event_id ya está aquí, el evento se confirma sin re-aplicarse (deduplicación).';
COMMENT ON COLUMN sync_ingest_log.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN sync_ingest_log.terminal_id IS 'Terminal que envió el evento.';
COMMENT ON COLUMN sync_ingest_log.event_id IS 'Identificador del evento generado por la terminal (UUIDv7, viene del outbox local); único global — es la clave de deduplicación.';
COMMENT ON COLUMN sync_ingest_log.event_type IS 'Tipo de evento aplicado (p. ej. sale.created, cash_session.closed); útil para auditoría y depuración.';
COMMENT ON COLUMN sync_ingest_log.received_at IS 'Momento en que el servidor recibió y aplicó el evento.';
