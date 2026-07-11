-- Estado de una terminal POS dentro del ciclo de enrolamiento M2M.
CREATE TYPE terminals.terminal_status AS ENUM (
    'PENDIENTE',    -- terminal creada en el panel, aún sin enrolar (sin credenciales)
    'ACTIVO',       -- terminal enrolada: tiene credenciales client_credentials vigentes
    'REVOCADO'      -- terminal dada de baja: sus credenciales ya no autentican
);

COMMENT ON TYPE terminals.terminal_status IS
    'Estado de enrolamiento de una terminal POS; solo ACTIVO puede autenticarse por client_credentials y sincronizar.';
