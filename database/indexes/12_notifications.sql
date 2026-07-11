-- =============================================================================
-- indexes/12_notifications.sql — Índices de notificaciones.
-- =============================================================================

CREATE INDEX ix_notifications__user_created ON notifications.notifications (user_id, created_at);
COMMENT ON INDEX notifications.ix_notifications__user_created IS 'Índice de FK user_id + listado de la campanita (las notificaciones de un usuario por fecha).';

CREATE INDEX ix_notifications__user_unread ON notifications.notifications (user_id) WHERE read_at IS NULL;
COMMENT ON INDEX notifications.ix_notifications__user_unread IS 'Contador del badge de la campanita (no leídas por usuario); parcial: las leídas no pesan.';
