-- =============================================================================
-- tables/03_terminals.sql — Terminales POS y su autenticación M2M.
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE terminals.terminals (
    id           uuid            NOT NULL DEFAULT uuidv7(),
    branch_id    uuid            NOT NULL,
    code         text            NOT NULL,
    name         text            NOT NULL,
    status       terminals.terminal_status NOT NULL DEFAULT 'PENDIENTE',
    enrolled_at  timestamptz     NULL,
    revoked_at   timestamptz     NULL,
    last_seen_at timestamptz     NULL,
    created_at   timestamptz     NOT NULL DEFAULT now(),
    updated_at   timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT pk_terminals PRIMARY KEY (id),
    CONSTRAINT ck_terminals__status_dates CHECK (
        (status = 'PENDIENTE' AND enrolled_at IS NULL AND revoked_at IS NULL)
        OR (status = 'ACTIVO' AND enrolled_at IS NOT NULL AND revoked_at IS NULL)
        OR (status = 'REVOCADO' AND revoked_at IS NOT NULL)
    )
);

COMMENT ON TABLE terminals.terminals IS
    'Puntos de venta físicos (PC con el POS de escritorio) registrados por sucursal. Se crean PENDIENTE en el panel, se enrolan con un código de un solo uso y quedan ACTIVO con credenciales M2M propias.';
COMMENT ON COLUMN terminals.terminals.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN terminals.terminals.branch_id IS 'Sucursal a la que pertenece la terminal.';
COMMENT ON COLUMN terminals.terminals.code IS 'Código corto único GLOBAL (p. ej. S01-T01), no por sucursal: es la serie de los comprobantes que numera la terminal offline, y una serie no puede repetirse entre tiendas (ux_sale_documents__doc chocaría al sincronizar).';
COMMENT ON COLUMN terminals.terminals.name IS 'Nombre descriptivo para mostrar (p. ej. "Caja principal").';
COMMENT ON COLUMN terminals.terminals.status IS 'Estado de enrolamiento (PENDIENTE → ACTIVO → REVOCADO); solo ACTIVO autentica y sincroniza.';
COMMENT ON COLUMN terminals.terminals.enrolled_at IS 'Momento en que completó el enrolamiento; NULL mientras esté PENDIENTE.';
COMMENT ON COLUMN terminals.terminals.revoked_at IS 'Momento en que fue dada de baja; NULL si no fue revocada.';
COMMENT ON COLUMN terminals.terminals.last_seen_at IS 'Último contacto con la API (sync o token); permite detectar terminales caídas desde el panel.';
COMMENT ON COLUMN terminals.terminals.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN terminals.terminals.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE terminals.terminal_enrollment_codes (
    id             uuid        NOT NULL DEFAULT uuidv7(),
    terminal_id    uuid        NOT NULL,
    code_hash      text        NOT NULL,
    created_by     uuid        NOT NULL,
    expires_at     timestamptz NOT NULL,
    used_at        timestamptz NULL,
    invalidated_at timestamptz NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_terminal_enrollment_codes PRIMARY KEY (id),
    CONSTRAINT ck_terminal_enrollment_codes__expires_after_created CHECK (expires_at > created_at)
);

COMMENT ON TABLE terminals.terminal_enrollment_codes IS
    'Códigos de enrolamiento de un solo uso (formato XXXX-XXXX-XXXX, vigencia 72 h). El código en claro se muestra una única vez en el panel; aquí solo vive su hash.';
COMMENT ON COLUMN terminals.terminal_enrollment_codes.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN terminals.terminal_enrollment_codes.terminal_id IS 'Terminal a la que enrola este código.';
COMMENT ON COLUMN terminals.terminal_enrollment_codes.code_hash IS 'Hash SHA-256 del código de enrolamiento; el claro nunca se persiste. Único.';
COMMENT ON COLUMN terminals.terminal_enrollment_codes.created_by IS 'Usuario del panel que generó el código (auditoría).';
COMMENT ON COLUMN terminals.terminal_enrollment_codes.expires_at IS 'Fecha límite para usar el código (~72 h desde su creación).';
COMMENT ON COLUMN terminals.terminal_enrollment_codes.used_at IS 'Momento en que se consumió; NULL = aún disponible. Un código usado jamás se reutiliza.';
COMMENT ON COLUMN terminals.terminal_enrollment_codes.invalidated_at IS 'Momento en que se invalidó sin usarse: la aplicación invalida el código anterior al generar uno nuevo para la misma terminal (a lo sumo un código utilizable por terminal). NULL = no invalidado.';
COMMENT ON COLUMN terminals.terminal_enrollment_codes.created_at IS 'Fecha de generación del código.';


CREATE TABLE terminals.terminal_credentials (
    id                 uuid        NOT NULL DEFAULT uuidv7(),
    terminal_id        uuid        NOT NULL,
    client_id          text        NOT NULL,
    client_secret_hash text        NOT NULL,
    last_used_at       timestamptz NULL,
    revoked_at         timestamptz NULL,
    created_at         timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_terminal_credentials PRIMARY KEY (id)
);

COMMENT ON TABLE terminals.terminal_credentials IS
    'Credenciales M2M (client_credentials) de cada terminal. El secreto en claro se entrega una sola vez al enrolar y la terminal lo cifra localmente (safeStorage/DPAPI). Rotar = revocar la fila vigente y crear una nueva.';
COMMENT ON COLUMN terminals.terminal_credentials.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN terminals.terminal_credentials.terminal_id IS 'Terminal dueña de estas credenciales.';
COMMENT ON COLUMN terminals.terminal_credentials.client_id IS 'Identificador público OAuth2 de la terminal; único, viaja en cada petición de token.';
COMMENT ON COLUMN terminals.terminal_credentials.client_secret_hash IS 'Hash argon2id del client_secret; el claro nunca se persiste en el servidor.';
COMMENT ON COLUMN terminals.terminal_credentials.last_used_at IS 'Última vez que estas credenciales pidieron un token; auditoría y detección de terminales caídas.';
COMMENT ON COLUMN terminals.terminal_credentials.revoked_at IS 'Momento de revocación; NULL = vigentes. Una terminal solo puede tener una credencial vigente (índice parcial).';
COMMENT ON COLUMN terminals.terminal_credentials.created_at IS 'Fecha de emisión de las credenciales.';
