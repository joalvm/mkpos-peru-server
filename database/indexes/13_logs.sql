-- =============================================================================
-- indexes/13_logs.sql — Índices de la telemetría HTTP.
-- Son índices PARTICIONADOS: se declaran sobre la tabla padre y Postgres los
-- crea automáticamente en cada partición mensual (también en las futuras que
-- cree logs.ensure_partitions()). Mínimos a propósito: los logs se escriben
-- millones de veces y se consultan pocas.
-- =============================================================================

CREATE INDEX ix_requests__subject ON logs.requests (subject_type, subject_id, created_at)
    WHERE subject_id IS NOT NULL;
COMMENT ON INDEX logs.ix_requests__subject IS 'Actividad de un usuario o terminal en el tiempo ("qué hizo la terminal S01-T01 ayer"); parcial: los requests anónimos no pesan.';

CREATE INDEX ix_requests__route ON logs.requests (route, created_at);
COMMENT ON INDEX logs.ix_requests__route IS 'Análisis por endpoint (volumen y latencias de una ruta en un rango de fechas).';

CREATE INDEX ix_requests__errors ON logs.requests (created_at) WHERE status >= 400;
COMMENT ON INDEX logs.ix_requests__errors IS 'Errores recientes ("qué falló hoy"); parcial: los 2xx —la inmensa mayoría— no pesan.';
