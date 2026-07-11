-- =============================================================================
-- indexes/05_customers.sql — Índices de clientes.
-- =============================================================================

CREATE UNIQUE INDEX ux_customers__doc ON customers (doc_type, doc_number);
COMMENT ON INDEX ux_customers__doc IS 'Un documento identifica a un solo cliente.';

CREATE INDEX ix_customers__updated_seq ON customers (updated_seq);
COMMENT ON INDEX ix_customers__updated_seq IS 'Escaneo por cursor del pull de sync.';
