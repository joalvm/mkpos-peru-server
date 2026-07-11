-- =============================================================================
-- tables/02_access.sql — Identidad y acceso (usuarios, RBAC, sesiones).
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE users (
    id            uuid        NOT NULL DEFAULT uuidv7(),
    full_name     text        NOT NULL,
    doc_number    text        NULL,
    username      text        NOT NULL,
    email         text        NULL,
    phone         text        NULL,
    password_hash text        NULL,
    pin_hash      text        NULL,
    is_active     boolean     NOT NULL DEFAULT true,
    updated_seq   bigint      NOT NULL DEFAULT nextval('sync_seq'),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_users PRIMARY KEY (id),
    CONSTRAINT ck_users__doc_number_format CHECK (doc_number IS NULL OR doc_number ~ '^[0-9]{8}$')
);

COMMENT ON TABLE users IS
    'Personas que usan el sistema: dueña y empleados. Qué puede hacer cada uno lo define user_roles (RBAC), no esta tabla.';
COMMENT ON COLUMN users.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN users.full_name IS 'Nombre completo de la persona, como aparece en tickets y reportes.';
COMMENT ON COLUMN users.doc_number IS 'DNI de la persona (8 dígitos); opcional, para planilla/identificación interna.';
COMMENT ON COLUMN users.username IS 'Nombre de usuario para iniciar sesión (único, sin distinción de mayúsculas — ver índice ux_users__username).';
COMMENT ON COLUMN users.email IS 'Correo electrónico; opcional (no todos los empleados tienen). Único cuando existe.';
COMMENT ON COLUMN users.phone IS 'Celular de contacto; opcional.';
COMMENT ON COLUMN users.password_hash IS 'Hash argon2id de la contraseña para web/móvil; NULL si la persona solo opera el POS con PIN. Nunca se guarda en claro.';
COMMENT ON COLUMN users.pin_hash IS 'Hash argon2id del PIN corto para el POS; se sincroniza a las terminales para login offline. NULL si no opera el POS.';
COMMENT ON COLUMN users.is_active IS 'false = ya no trabaja aquí; conserva historial de sus ventas (soft delete).';
COMMENT ON COLUMN users.updated_seq IS 'Posición en el reloj lógico de sync; permite al POS descargar altas/bajas y cambios de PIN.';
COMMENT ON COLUMN users.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN users.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE roles (
    id          uuid        NOT NULL DEFAULT uuidv7(),
    code        text        NOT NULL,
    name        text        NOT NULL,
    description text        NULL,
    is_system   boolean     NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_roles PRIMARY KEY (id)
);

COMMENT ON TABLE roles IS
    'Roles del RBAC. Semilla del sistema: PROPIETARIO, ENCARGADO, CAJERO (códigos en español, regla del proyecto). La dueña puede crear roles propios.';
COMMENT ON COLUMN roles.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN roles.code IS 'Código estable del rol, en español y mayúsculas ASCII (PROPIETARIO, ENCARGADO, CAJERO); único, referenciado por código en la lógica.';
COMMENT ON COLUMN roles.name IS 'Nombre del rol para mostrar en la interfaz.';
COMMENT ON COLUMN roles.description IS 'Descripción de qué hace este rol; opcional.';
COMMENT ON COLUMN roles.is_system IS 'true = rol sembrado por el sistema: no se puede eliminar ni renombrar desde la interfaz.';
COMMENT ON COLUMN roles.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN roles.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE permissions (
    id          uuid        NOT NULL DEFAULT uuidv7(),
    code        text        NOT NULL,
    description text        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_permissions PRIMARY KEY (id)
);

COMMENT ON TABLE permissions IS
    'Catálogo de permisos del RBAC, sembrado por seeds/system.sql. Los códigos son identificadores técnicos ligados a endpoints, por eso van en inglés (sales.create), a diferencia de los enums de negocio.';
COMMENT ON COLUMN permissions.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN permissions.code IS 'Código estable del permiso en formato recurso.accion (p. ej. sales.create, cash.open); único.';
COMMENT ON COLUMN permissions.description IS 'Descripción en español de qué autoriza este permiso.';
COMMENT ON COLUMN permissions.created_at IS 'Fecha de creación del registro.';


CREATE TABLE role_permissions (
    role_id       uuid        NOT NULL,
    permission_id uuid        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, permission_id)
);

COMMENT ON TABLE role_permissions IS
    'Permisos otorgados a cada rol (N:M). Al POS se le envía siempre el snapshot completo del RBAC en cada pull (tabla pequeña; evita el problema de tombstones al revocar).';
COMMENT ON COLUMN role_permissions.role_id IS 'Rol que recibe el permiso.';
COMMENT ON COLUMN role_permissions.permission_id IS 'Permiso otorgado.';
COMMENT ON COLUMN role_permissions.created_at IS 'Fecha en que se otorgó el permiso.';


CREATE TABLE user_roles (
    id         uuid        NOT NULL DEFAULT uuidv7(),
    user_id    uuid        NOT NULL,
    role_id    uuid        NOT NULL,
    branch_id  uuid        NULL,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_user_roles PRIMARY KEY (id)
);

COMMENT ON TABLE user_roles IS
    'Asignación de roles a usuarios, con alcance opcional por sucursal. Una persona puede ser ENCARGADO en una tienda y CAJERO en otra.';
COMMENT ON COLUMN user_roles.id IS 'Identificador único (UUIDv7); PK subrogada porque branch_id nullable no puede formar parte de una PK compuesta.';
COMMENT ON COLUMN user_roles.user_id IS 'Usuario que recibe el rol.';
COMMENT ON COLUMN user_roles.role_id IS 'Rol asignado.';
COMMENT ON COLUMN user_roles.branch_id IS 'Sucursal donde aplica el rol; NULL = aplica en todas las sucursales (típico para PROPIETARIO).';
COMMENT ON COLUMN user_roles.created_at IS 'Fecha de la asignación.';


CREATE TABLE refresh_tokens (
    id             uuid        NOT NULL DEFAULT uuidv7(),
    user_id        uuid        NOT NULL,
    token_hash     text        NOT NULL,
    expires_at     timestamptz NOT NULL,
    revoked_at     timestamptz NULL,
    replaced_by_id uuid        NULL,
    user_agent     text        NULL,
    created_ip     inet        NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_refresh_tokens PRIMARY KEY (id),
    CONSTRAINT ck_refresh_tokens__expires_after_created CHECK (expires_at > created_at)
);

COMMENT ON TABLE refresh_tokens IS
    'Refresh tokens rotativos de las sesiones web/móvil (humanos; las terminales usan client_credentials). En cada refresh el token viejo se marca revocado y apunta al nuevo; si un token ya rotado se reusa, se revoca toda la cadena (detección de robo).';
COMMENT ON COLUMN refresh_tokens.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN refresh_tokens.user_id IS 'Usuario dueño de la sesión.';
COMMENT ON COLUMN refresh_tokens.token_hash IS 'Hash SHA-256 del refresh token; el token en claro solo lo tiene el cliente. Único.';
COMMENT ON COLUMN refresh_tokens.expires_at IS 'Fecha de expiración absoluta del token (~30 días).';
COMMENT ON COLUMN refresh_tokens.revoked_at IS 'Momento en que se revocó (rotación, logout o detección de reuso); NULL = vigente.';
COMMENT ON COLUMN refresh_tokens.replaced_by_id IS 'Token que lo reemplazó al rotar; forma la cadena de rotación. FK con ON DELETE SET NULL (excepción documentada a RESTRICT: permite depurar tokens viejos sin romper la cadena).';
COMMENT ON COLUMN refresh_tokens.user_agent IS 'User-Agent del cliente al crear la sesión; para que el usuario reconozca sus sesiones.';
COMMENT ON COLUMN refresh_tokens.created_ip IS 'IP desde la que se creó la sesión; auditoría.';
COMMENT ON COLUMN refresh_tokens.created_at IS 'Fecha de emisión del token.';
