-- =============================================================================
-- indexes/03_terminals.sql — Índices de terminales y credenciales M2M.
-- =============================================================================

CREATE UNIQUE INDEX ux_terminals__code ON terminals.terminals (code);
COMMENT ON INDEX terminals.ux_terminals__code IS 'Código de terminal único GLOBAL: es la serie de sus comprobantes y una serie no puede repetirse entre tiendas.';

CREATE INDEX ix_terminals__branch_id ON terminals.terminals (branch_id);
COMMENT ON INDEX terminals.ix_terminals__branch_id IS 'Índice de FK: terminales de una sucursal.';

CREATE UNIQUE INDEX ux_terminal_enrollment_codes__code_hash
    ON terminals.terminal_enrollment_codes (code_hash);
COMMENT ON INDEX terminals.ux_terminal_enrollment_codes__code_hash IS 'Búsqueda del código presentado al enrolar; único.';

CREATE INDEX ix_terminal_enrollment_codes__terminal_id
    ON terminals.terminal_enrollment_codes (terminal_id);
COMMENT ON INDEX terminals.ix_terminal_enrollment_codes__terminal_id IS 'Índice de FK terminal_id.';

CREATE INDEX ix_terminal_enrollment_codes__created_by
    ON terminals.terminal_enrollment_codes (created_by);
COMMENT ON INDEX terminals.ix_terminal_enrollment_codes__created_by IS 'Índice de FK created_by.';

CREATE UNIQUE INDEX ux_terminal_credentials__client_id ON terminals.terminal_credentials (client_id);
COMMENT ON INDEX terminals.ux_terminal_credentials__client_id IS 'Búsqueda por client_id en cada petición de token M2M; único.';

CREATE UNIQUE INDEX ux_terminal_credentials__active_per_terminal
    ON terminals.terminal_credentials (terminal_id) WHERE revoked_at IS NULL;
COMMENT ON INDEX terminals.ux_terminal_credentials__active_per_terminal IS 'Garantiza a lo sumo una credencial vigente por terminal.';

CREATE INDEX ix_terminal_credentials__terminal_id ON terminals.terminal_credentials (terminal_id);
COMMENT ON INDEX terminals.ix_terminal_credentials__terminal_id IS 'Índice de FK completo (el único parcial no cubre credenciales revocadas).';
