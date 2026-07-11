-- =============================================================================
-- tables/11_reports.sql — Reportes generados en segundo plano.
-- La tabla ES su propia cola de trabajo: los workers (goroutines del binario
-- API) toman filas PENDIENTE con FOR UPDATE SKIP LOCKED. Sin Redis ni broker
-- externo a propósito; una tabla de jobs genérica recién existirá cuando haya
-- un segundo consumidor de cola (p. ej. envío de emails).
-- Los reportes rápidos de F1 (GET /reports/sales-daily…) son consultas
-- síncronas y NO pasan por aquí: esta tabla es para exports pesados
-- (kardex, cierres mensuales, Excel) que tardan más que un request.
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE reports.reports (
    id              uuid                  NOT NULL DEFAULT uuidv7(),
    kind            text                  NOT NULL,
    params          jsonb                 NOT NULL DEFAULT '{}'::jsonb,
    status          reports.report_status NOT NULL DEFAULT 'PENDIENTE',
    requested_by    uuid                  NOT NULL,
    attempts        smallint              NOT NULL DEFAULT 0,
    started_at      timestamptz           NULL,
    finished_at     timestamptz           NULL,
    error           text                  NULL,
    file_path       text                  NULL,
    file_name       text                  NULL,
    file_mime       text                  NULL,
    file_size_bytes bigint                NULL,
    expires_at      timestamptz           NULL,
    created_at      timestamptz           NOT NULL DEFAULT now(),
    updated_at      timestamptz           NOT NULL DEFAULT now(),

    CONSTRAINT pk_reports PRIMARY KEY (id),
    CONSTRAINT ck_reports__kind_format CHECK (kind ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT ck_reports__attempts_non_negative CHECK (attempts >= 0),
    CONSTRAINT ck_reports__file_size_non_negative CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
    CONSTRAINT ck_reports__status_coherence CHECK (
        (status = 'PENDIENTE' AND started_at IS NULL AND finished_at IS NULL)
        OR (status = 'EN_PROCESO' AND started_at IS NOT NULL AND finished_at IS NULL)
        OR (status = 'COMPLETADO' AND started_at IS NOT NULL AND finished_at IS NOT NULL
            AND file_path IS NOT NULL AND file_name IS NOT NULL AND file_mime IS NOT NULL
            AND file_size_bytes IS NOT NULL)
        OR (status = 'FALLIDO' AND started_at IS NOT NULL AND finished_at IS NOT NULL
            AND error IS NOT NULL)
    )
);

COMMENT ON TABLE reports.reports IS
    'Reportes solicitados por usuarios y generados en segundo plano. Doble rol: estado visible al usuario (POST /reports responde 202 con esta fila; GET /reports/{id} la consulta) y cola de trabajo de los workers (SKIP LOCKED sobre status = PENDIENTE, orden FIFO por created_at). Al completarse se notifica al solicitante por la campanita (notifications).';
COMMENT ON COLUMN reports.reports.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN reports.reports.kind IS 'Código del tipo de reporte, valor de negocio en español mayúsculas (p. ej. VENTAS_MENSUAL, KARDEX_PRODUCTO). El registro de tipos válidos y sus parámetros vive en el código del server (internal/reports); el CHECK solo valida el formato.';
COMMENT ON COLUMN reports.reports.params IS 'Parámetros del reporte tal como los pidió el usuario (rango de fechas, sucursal, producto…), en JSON. El worker los valida contra el registro del kind.';
COMMENT ON COLUMN reports.reports.status IS 'Ciclo de vida: PENDIENTE → EN_PROCESO → COMPLETADO | FALLIDO (CHECK de coherencia con fechas y archivo).';
COMMENT ON COLUMN reports.reports.requested_by IS 'Usuario que solicitó el reporte; único que lo ve y descarga (además de quien tenga reports.read global).';
COMMENT ON COLUMN reports.reports.attempts IS 'Intentos de generación consumidos por el worker (reintentos internos ante errores transitorios); auditoría de estabilidad.';
COMMENT ON COLUMN reports.reports.started_at IS 'Momento en que un worker tomó el reporte; NULL mientras esté PENDIENTE.';
COMMENT ON COLUMN reports.reports.finished_at IS 'Momento en que terminó (bien o mal); NULL hasta entonces.';
COMMENT ON COLUMN reports.reports.error IS 'Mensaje de error en español si FALLIDO (se muestra al usuario); NULL en el resto de estados.';
COMMENT ON COLUMN reports.reports.file_path IS 'Ruta del archivo generado dentro del storage del server (interfaz internal/storage; disco local en v1). NULL hasta COMPLETADO.';
COMMENT ON COLUMN reports.reports.file_name IS 'Nombre de descarga amigable del archivo (p. ej. ventas-2026-07.xlsx).';
COMMENT ON COLUMN reports.reports.file_mime IS 'Content-Type del archivo (text/csv, application/vnd.openxmlformats…).';
COMMENT ON COLUMN reports.reports.file_size_bytes IS 'Tamaño del archivo en bytes; se muestra antes de descargar.';
COMMENT ON COLUMN reports.reports.expires_at IS 'Fecha en que el archivo deja de estar disponible: el janitor del server borra el archivo físico vencido (la fila se conserva como historial; descargar después responde 410).';
COMMENT ON COLUMN reports.reports.created_at IS 'Fecha de solicitud del reporte; define el orden FIFO de la cola.';
COMMENT ON COLUMN reports.reports.updated_at IS 'Fecha de última modificación (mantenida por trigger).';
