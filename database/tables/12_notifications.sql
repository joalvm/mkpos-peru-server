-- =============================================================================
-- tables/12_notifications.sql — Notificaciones internas (campanita).
-- Aparecen en el panel web y en la app móvil; NO se sincronizan al POS (la
-- campanita exige estar online y los cajeros no la usan). Fanout-on-write:
-- una fila por destinatario — a esta escala (un puñado de usuarios) es lo
-- simple y lo correcto. Entrega v1 por polling del cliente; un stream SSE
-- sería una mejora aditiva futura sin tocar esta tabla.
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE notifications.notifications (
    id         uuid        NOT NULL DEFAULT uuidv7(),
    user_id    uuid        NOT NULL,
    type       text        NOT NULL,
    title      text        NOT NULL,
    body       text        NULL,
    data       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    read_at    timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_notifications PRIMARY KEY (id),
    CONSTRAINT ck_notifications__type_format CHECK (type ~ '^[A-Z][A-Z0-9_]*$')
);

COMMENT ON TABLE notifications.notifications IS
    'Notificaciones de la campanita para usuarios del panel/app móvil (una fila por destinatario). Primer emisor: reportes en segundo plano al completarse (REPORTE_LISTO); luego alertas de stock mínimo (STOCK_BAJO, F4). Marcar como leída = fijar read_at (idempotente); no se borran, el listado pagina por fecha.';
COMMENT ON COLUMN notifications.notifications.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN notifications.notifications.user_id IS 'Usuario destinatario; cada quien ve solo las suyas (no hay notificaciones "globales": el emisor hace fanout a los destinatarios que correspondan).';
COMMENT ON COLUMN notifications.notifications.type IS 'Código del tipo de notificación, valor de negocio en español mayúsculas (REPORTE_LISTO, STOCK_BAJO…). El registro de tipos vive en el código del server (internal/notify); la UI elige ícono y navegación según este código.';
COMMENT ON COLUMN notifications.notifications.title IS 'Título corto que se muestra en la campanita.';
COMMENT ON COLUMN notifications.notifications.body IS 'Texto secundario opcional (detalle de la notificación).';
COMMENT ON COLUMN notifications.notifications.data IS 'Payload JSON para el deep-link de la UI (p. ej. {"report_id": "…"} para abrir el reporte listo); su forma depende de type.';
COMMENT ON COLUMN notifications.notifications.read_at IS 'Momento en que el usuario la leyó; NULL = no leída (el badge de la campanita cuenta estas). Solo avanza: no existe "marcar como no leída".';
COMMENT ON COLUMN notifications.notifications.created_at IS 'Fecha de emisión de la notificación.';
COMMENT ON COLUMN notifications.notifications.updated_at IS 'Fecha de última modificación (mantenida por trigger; cambia al marcarse leída).';
