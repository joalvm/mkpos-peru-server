-- Tipo de documento de identidad de un cliente registrado. Solo se registran
-- clientes cuando piden comprobante con sus datos (boleta/factura futuras).
CREATE TYPE customers.customer_doc_type AS ENUM (
    'DNI',  -- documento nacional de identidad (persona natural, 8 dígitos)
    'RUC'   -- registro único de contribuyentes (empresa, 11 dígitos)
);

COMMENT ON TYPE customers.customer_doc_type IS
    'Tipo de documento de identidad del cliente; el formato del número se valida por CHECK (DNI 8 dígitos, RUC 11 dígitos).';
