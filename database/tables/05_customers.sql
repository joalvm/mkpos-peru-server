-- =============================================================================
-- tables/05_customers.sql — Clientes identificados (solo para comprobantes).
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE customers (
    id          uuid              NOT NULL DEFAULT uuidv7(),
    doc_type    customer_doc_type NOT NULL,
    doc_number  text              NOT NULL,
    name        text              NOT NULL,
    address     text              NULL,
    email       text              NULL,
    phone       text              NULL,
    updated_seq bigint            NOT NULL DEFAULT nextval('sync_seq'),
    created_at  timestamptz       NOT NULL DEFAULT now(),
    updated_at  timestamptz       NOT NULL DEFAULT now(),

    CONSTRAINT pk_customers PRIMARY KEY (id),
    CONSTRAINT ck_customers__doc_number_format CHECK (
        (doc_type = 'DNI' AND doc_number ~ '^[0-9]{8}$')
        OR (doc_type = 'RUC' AND doc_number ~ '^[0-9]{11}$')
    )
);

COMMENT ON TABLE customers IS
    'Clientes identificados. La venta normal es anónima (no se fía); solo se registra un cliente cuando pide comprobante con sus datos — hoy nota de venta nominada, mañana boleta/factura. Nota SUNAT: la boleta electrónica desde S/ 700 exige identificar al cliente (regla de aplicación en F3).';
COMMENT ON COLUMN customers.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN customers.doc_type IS 'Tipo de documento: DNI (persona) o RUC (empresa). Futuro previsto (ADD VALUE, F3): CE y PASAPORTE para extranjeros.';
COMMENT ON COLUMN customers.doc_number IS 'Número de documento; formato validado por CHECK (DNI 8 dígitos, RUC 11). Único junto con doc_type.';
COMMENT ON COLUMN customers.name IS 'Nombre completo o razón social, según el tipo de documento.';
COMMENT ON COLUMN customers.address IS 'Dirección fiscal o de contacto; requerida recién para FACTURA (se valida en la aplicación).';
COMMENT ON COLUMN customers.email IS 'Correo para enviar comprobantes electrónicos (futuro PSE); opcional.';
COMMENT ON COLUMN customers.phone IS 'Teléfono de contacto; opcional.';
COMMENT ON COLUMN customers.updated_seq IS 'Posición en el reloj lógico de sync; el POS descarga clientes para emitir comprobantes offline.';
COMMENT ON COLUMN customers.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN customers.updated_at IS 'Fecha de última modificación (mantenida por trigger).';
