-- =============================================================================
-- indexes/08_cash.sql — Índices de caja.
-- =============================================================================

CREATE UNIQUE INDEX ux_cash_sessions__open_per_terminal
    ON cash.cash_sessions (terminal_id) WHERE closed_at IS NULL;
COMMENT ON INDEX cash.ux_cash_sessions__open_per_terminal IS 'Garantiza a lo sumo una sesión de caja abierta por terminal.';

CREATE INDEX ix_cash_sessions__terminal_id ON cash.cash_sessions (terminal_id);
COMMENT ON INDEX cash.ix_cash_sessions__terminal_id IS 'Índice de FK completo (el único parcial no cubre sesiones cerradas).';

CREATE INDEX ix_cash_sessions__branch_opened ON cash.cash_sessions (branch_id, opened_at);
COMMENT ON INDEX cash.ix_cash_sessions__branch_opened IS 'Historial de arqueos por sucursal y fecha; cubre además la FK branch_id.';

CREATE INDEX ix_cash_sessions__opened_by ON cash.cash_sessions (opened_by);
COMMENT ON INDEX cash.ix_cash_sessions__opened_by IS 'Índice de FK opened_by.';

CREATE INDEX ix_cash_sessions__closed_by ON cash.cash_sessions (closed_by) WHERE closed_by IS NOT NULL;
COMMENT ON INDEX cash.ix_cash_sessions__closed_by IS 'Índice de FK closed_by; parcial (NULL mientras la sesión está abierta).';

CREATE INDEX ix_cash_movements__cash_session_id ON cash.cash_movements (cash_session_id);
COMMENT ON INDEX cash.ix_cash_movements__cash_session_id IS 'Índice de FK: movimientos de una sesión (cálculo del arqueo).';

CREATE INDEX ix_cash_movements__user_id ON cash.cash_movements (user_id);
COMMENT ON INDEX cash.ix_cash_movements__user_id IS 'Índice de FK: auditoría de ingresos/retiros por usuario.';
