-- =============================================================================
-- indexes/05_customers.sql — Índices de clientes.
-- =============================================================================

CREATE UNIQUE INDEX ux_customers__doc ON customers.customers (doc_type, doc_number);
COMMENT ON INDEX customers.ux_customers__doc IS 'Un documento identifica a un solo cliente.';

CREATE INDEX ix_customers__updated_seq ON customers.customers (updated_seq);
COMMENT ON INDEX customers.ix_customers__updated_seq IS 'Escaneo por cursor del pull de sync.';
