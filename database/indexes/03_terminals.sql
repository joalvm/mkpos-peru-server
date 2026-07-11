-- =============================================================================
-- indexes/03_terminals.sql — Índices de terminales y credenciales M2M.
-- =============================================================================

CREATE UNIQUE INDEX ux_terminals__code ON terminals (code);
COMMENT ON INDEX ux_terminals__code IS 'Código de terminal único GLOBAL: es la serie de sus comprobantes y una serie no puede repetirse entre tiendas.';

CREATE INDEX ix_terminals__branch_id ON terminals (branch_id);
COMMENT ON INDEX ix_terminals__branch_id IS 'Índice de FK: terminales de una sucursal.';

CREATE UNIQUE INDEX ux_terminal_enrollment_codes__code_hash
    ON terminal_enrollment_codes (code_hash);
COMMENT ON INDEX ux_terminal_enrollment_codes__code_hash IS 'Búsqueda del código presentado al enrolar; único.';

CREATE INDEX ix_terminal_enrollment_codes__terminal_id
    ON terminal_enrollment_codes (terminal_id);
COMMENT ON INDEX ix_terminal_enrollment_codes__terminal_id IS 'Índice de FK terminal_id.';

CREATE INDEX ix_terminal_enrollment_codes__created_by
    ON terminal_enrollment_codes (created_by);
COMMENT ON INDEX ix_terminal_enrollment_codes__created_by IS 'Índice de FK created_by.';

CREATE UNIQUE INDEX ux_terminal_credentials__client_id ON terminal_credentials (client_id);
COMMENT ON INDEX ux_terminal_credentials__client_id IS 'Búsqueda por client_id en cada petición de token M2M; único.';

CREATE UNIQUE INDEX ux_terminal_credentials__active_per_terminal
    ON terminal_credentials (terminal_id) WHERE revoked_at IS NULL;
COMMENT ON INDEX ux_terminal_credentials__active_per_terminal IS 'Garantiza a lo sumo una credencial vigente por terminal.';

CREATE INDEX ix_terminal_credentials__terminal_id ON terminal_credentials (terminal_id);
COMMENT ON INDEX ix_terminal_credentials__terminal_id IS 'Índice de FK completo (el único parcial no cubre credenciales revocadas).';
