-- =============================================================================
-- indexes/02_access.sql — Índices de identidad y acceso.
-- =============================================================================

CREATE UNIQUE INDEX ux_users__username ON users (lower(username));
COMMENT ON INDEX ux_users__username IS 'Username único sin distinción de mayúsculas.';

CREATE UNIQUE INDEX ux_users__email ON users (lower(email)) WHERE email IS NOT NULL;
COMMENT ON INDEX ux_users__email IS 'Email único (cuando existe), sin distinción de mayúsculas.';

CREATE INDEX ix_users__updated_seq ON users (updated_seq);
COMMENT ON INDEX ix_users__updated_seq IS 'Escaneo por cursor del pull de sync.';

CREATE UNIQUE INDEX ux_roles__code ON roles (code);
COMMENT ON INDEX ux_roles__code IS 'Código de rol único (PROPIETARIO, ENCARGADO, CAJERO…).';

CREATE UNIQUE INDEX ux_permissions__code ON permissions (code);
COMMENT ON INDEX ux_permissions__code IS 'Código de permiso único (sales.create, cash.open…).';

CREATE INDEX ix_role_permissions__permission_id ON role_permissions (permission_id);
COMMENT ON INDEX ix_role_permissions__permission_id IS 'Índice de FK: la PK compuesta solo cubre role_id.';

CREATE UNIQUE INDEX ux_user_roles__assignment
    ON user_roles (user_id, role_id, branch_id) NULLS NOT DISTINCT;
COMMENT ON INDEX ux_user_roles__assignment IS
    'Evita asignaciones duplicadas; NULLS NOT DISTINCT trata branch_id NULL (todas las sucursales) como un valor: no se puede repetir el rol global.';

CREATE INDEX ix_user_roles__role_id ON user_roles (role_id);
COMMENT ON INDEX ix_user_roles__role_id IS 'Índice de FK role_id.';

CREATE INDEX ix_user_roles__branch_id ON user_roles (branch_id);
COMMENT ON INDEX ix_user_roles__branch_id IS 'Índice de FK branch_id.';

CREATE UNIQUE INDEX ux_refresh_tokens__token_hash ON refresh_tokens (token_hash);
COMMENT ON INDEX ux_refresh_tokens__token_hash IS 'Búsqueda del token presentado en /auth/refresh; único.';

CREATE INDEX ix_refresh_tokens__user_id ON refresh_tokens (user_id);
COMMENT ON INDEX ix_refresh_tokens__user_id IS 'Índice de FK: listar/revocar sesiones de un usuario.';

CREATE INDEX ix_refresh_tokens__replaced_by_id ON refresh_tokens (replaced_by_id)
    WHERE replaced_by_id IS NOT NULL;
COMMENT ON INDEX ix_refresh_tokens__replaced_by_id IS 'Índice de FK: recorrer la cadena de rotación al detectar reuso.';

CREATE INDEX ix_refresh_tokens__active_expiry ON refresh_tokens (expires_at)
    WHERE revoked_at IS NULL;
COMMENT ON INDEX ix_refresh_tokens__active_expiry IS 'Limpieza periódica de tokens vigentes ya expirados.';
