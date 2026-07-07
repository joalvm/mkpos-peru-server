-- =============================================================================
-- tables.sql — Definición completa de tablas del sistema Minimarket POS.
--
-- Convenciones (PROYECTO.md § 6 y § 7):
--   · PK uuid DEFAULT uuidv7() (PostgreSQL 18, ordenable por tiempo).
--   · Dinero en bigint con sufijo _cents (céntimos de sol); nunca float.
--   · Cantidades de producto en numeric(10,3) (granel: 0.250 kg).
--   · Fechas timestamptz; created_at/updated_at en tablas mutables;
--     las tablas-libro (movimientos, pagos, ítems) son inmutables: solo created_at.
--   · updated_seq bigint solo en tablas que el POS descarga por pull
--     incremental (DEFAULT nextval('sync_seq') + trigger en UPDATE).
--   · Constraints nombrados: pk_ / ck_ (únicos e índices viven en indexes.sql).
--   · TODAS las claves foráneas se declaran AL FINAL de este archivo
--     (sección RELACIONES), nunca dentro del CREATE TABLE.
--   · Todo objeto y columna lleva COMMENT en español.
--
-- Orden de dominios:
--   1. Organización e identidad   2. Terminales (M2M)   3. Catálogo
--   4. Clientes                   5. Ventas             6. Inventario
--   7. Caja                       8. Compras            9. Sincronización
-- =============================================================================


-- =============================================================================
-- 1. ORGANIZACIÓN E IDENTIDAD
-- =============================================================================

CREATE TABLE branches (
    id          uuid        NOT NULL DEFAULT uuidv7(),
    code        text        NOT NULL,
    name        text        NOT NULL,
    address     text        NULL,
    phone       text        NULL,
    is_active   boolean     NOT NULL DEFAULT true,
    updated_seq bigint      NOT NULL DEFAULT nextval('sync_seq'),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_branches PRIMARY KEY (id)
);

COMMENT ON TABLE branches IS
    'Sucursales (tiendas físicas) de la cadena. Todo lo operativo (ventas, stock, caja, terminales) cuelga de una sucursal.';
COMMENT ON COLUMN branches.id IS 'Identificador único (UUIDv7, ordenable por tiempo).';
COMMENT ON COLUMN branches.code IS 'Código corto legible y único de la sucursal (p. ej. S01); se usa en reportes y tickets.';
COMMENT ON COLUMN branches.name IS 'Nombre comercial de la sucursal (p. ej. "Minimarket Los Olivos").';
COMMENT ON COLUMN branches.address IS 'Dirección física de la tienda; opcional.';
COMMENT ON COLUMN branches.phone IS 'Teléfono de contacto de la tienda; opcional.';
COMMENT ON COLUMN branches.is_active IS 'false = sucursal cerrada u operativamente deshabilitada; nunca se borra (soft delete).';
COMMENT ON COLUMN branches.updated_seq IS 'Posición en el reloj lógico de sync (secuencia sync_seq); el POS descarga cambios con updated_seq > su cursor.';
COMMENT ON COLUMN branches.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN branches.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


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


-- =============================================================================
-- 2. TERMINALES (M2M)
-- =============================================================================

CREATE TABLE terminals (
    id           uuid            NOT NULL DEFAULT uuidv7(),
    branch_id    uuid            NOT NULL,
    code         text            NOT NULL,
    name         text            NOT NULL,
    status       terminal_status NOT NULL DEFAULT 'PENDIENTE',
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

COMMENT ON TABLE terminals IS
    'Puntos de venta físicos (PC con el POS de escritorio) registrados por sucursal. Se crean PENDIENTE en el panel, se enrolan con un código de un solo uso y quedan ACTIVO con credenciales M2M propias.';
COMMENT ON COLUMN terminals.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN terminals.branch_id IS 'Sucursal a la que pertenece la terminal.';
COMMENT ON COLUMN terminals.code IS 'Código corto único por sucursal (p. ej. T01). Además define la serie de los comprobantes locales de esa terminal (numeración sin coordinación central).';
COMMENT ON COLUMN terminals.name IS 'Nombre descriptivo para mostrar (p. ej. "Caja principal").';
COMMENT ON COLUMN terminals.status IS 'Estado de enrolamiento (PENDIENTE → ACTIVO → REVOCADO); solo ACTIVO autentica y sincroniza.';
COMMENT ON COLUMN terminals.enrolled_at IS 'Momento en que completó el enrolamiento; NULL mientras esté PENDIENTE.';
COMMENT ON COLUMN terminals.revoked_at IS 'Momento en que fue dada de baja; NULL si no fue revocada.';
COMMENT ON COLUMN terminals.last_seen_at IS 'Último contacto con la API (sync o token); permite detectar terminales caídas desde el panel.';
COMMENT ON COLUMN terminals.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN terminals.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE terminal_enrollment_codes (
    id          uuid        NOT NULL DEFAULT uuidv7(),
    terminal_id uuid        NOT NULL,
    code_hash   text        NOT NULL,
    created_by  uuid        NOT NULL,
    expires_at  timestamptz NOT NULL,
    used_at     timestamptz NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_terminal_enrollment_codes PRIMARY KEY (id),
    CONSTRAINT ck_terminal_enrollment_codes__expires_after_created CHECK (expires_at > created_at)
);

COMMENT ON TABLE terminal_enrollment_codes IS
    'Códigos de enrolamiento de un solo uso (formato XXXX-XXXX-XXXX, vigencia 72 h). El código en claro se muestra una única vez en el panel; aquí solo vive su hash.';
COMMENT ON COLUMN terminal_enrollment_codes.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN terminal_enrollment_codes.terminal_id IS 'Terminal a la que enrola este código.';
COMMENT ON COLUMN terminal_enrollment_codes.code_hash IS 'Hash SHA-256 del código de enrolamiento; el claro nunca se persiste. Único.';
COMMENT ON COLUMN terminal_enrollment_codes.created_by IS 'Usuario del panel que generó el código (auditoría).';
COMMENT ON COLUMN terminal_enrollment_codes.expires_at IS 'Fecha límite para usar el código (~72 h desde su creación).';
COMMENT ON COLUMN terminal_enrollment_codes.used_at IS 'Momento en que se consumió; NULL = aún disponible. Un código usado jamás se reutiliza.';
COMMENT ON COLUMN terminal_enrollment_codes.created_at IS 'Fecha de generación del código.';


CREATE TABLE terminal_credentials (
    id                 uuid        NOT NULL DEFAULT uuidv7(),
    terminal_id        uuid        NOT NULL,
    client_id          text        NOT NULL,
    client_secret_hash text        NOT NULL,
    last_used_at       timestamptz NULL,
    revoked_at         timestamptz NULL,
    created_at         timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_terminal_credentials PRIMARY KEY (id)
);

COMMENT ON TABLE terminal_credentials IS
    'Credenciales M2M (client_credentials) de cada terminal. El secreto en claro se entrega una sola vez al enrolar y la terminal lo cifra localmente (safeStorage/DPAPI). Rotar = revocar la fila vigente y crear una nueva.';
COMMENT ON COLUMN terminal_credentials.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN terminal_credentials.terminal_id IS 'Terminal dueña de estas credenciales.';
COMMENT ON COLUMN terminal_credentials.client_id IS 'Identificador público OAuth2 de la terminal; único, viaja en cada petición de token.';
COMMENT ON COLUMN terminal_credentials.client_secret_hash IS 'Hash argon2id del client_secret; el claro nunca se persiste en el servidor.';
COMMENT ON COLUMN terminal_credentials.last_used_at IS 'Última vez que estas credenciales pidieron un token; auditoría y detección de terminales caídas.';
COMMENT ON COLUMN terminal_credentials.revoked_at IS 'Momento de revocación; NULL = vigentes. Una terminal solo puede tener una credencial vigente (índice parcial).';
COMMENT ON COLUMN terminal_credentials.created_at IS 'Fecha de emisión de las credenciales.';


-- =============================================================================
-- 3. CATÁLOGO
-- =============================================================================

CREATE TABLE categories (
    id            uuid        NOT NULL DEFAULT uuidv7(),
    name          text        NOT NULL,
    display_order integer     NOT NULL DEFAULT 0,
    is_active     boolean     NOT NULL DEFAULT true,
    updated_seq   bigint      NOT NULL DEFAULT nextval('sync_seq'),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_categories PRIMARY KEY (id)
);

COMMENT ON TABLE categories IS
    'Categorías de productos (abarrotes, bebidas, limpieza…). Jerarquía plana a propósito: un minimarket no necesita árbol de categorías.';
COMMENT ON COLUMN categories.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN categories.name IS 'Nombre de la categoría; único sin distinción de mayúsculas (índice ux_categories__name).';
COMMENT ON COLUMN categories.display_order IS 'Orden de aparición en la interfaz del POS (botonera de categorías); menor = primero.';
COMMENT ON COLUMN categories.is_active IS 'false = categoría oculta en interfaces; no se borra porque productos históricos la referencian.';
COMMENT ON COLUMN categories.updated_seq IS 'Posición en el reloj lógico de sync para el pull incremental del POS.';
COMMENT ON COLUMN categories.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN categories.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE products (
    id               uuid          NOT NULL DEFAULT uuidv7(),
    category_id      uuid          NOT NULL,
    barcode          text          NULL,
    name             text          NOT NULL,
    unit_type        unit_type     NOT NULL,
    sale_price_cents bigint        NOT NULL,
    cost_cents       bigint        NULL,
    min_stock        numeric(10,3) NOT NULL DEFAULT 0,
    is_active        boolean       NOT NULL DEFAULT true,
    updated_seq      bigint        NOT NULL DEFAULT nextval('sync_seq'),
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_products PRIMARY KEY (id),
    CONSTRAINT ck_products__sale_price_non_negative CHECK (sale_price_cents >= 0),
    CONSTRAINT ck_products__cost_non_negative CHECK (cost_cents IS NULL OR cost_cents >= 0),
    CONSTRAINT ck_products__min_stock_non_negative CHECK (min_stock >= 0)
);

COMMENT ON TABLE products IS
    'Catálogo de productos. Incluye productos con código de barras y productos a granel sin código (arroz, azúcar) que se buscan por nombre. El precio vigente vive aquí; el precio histórico de cada venta queda congelado en sale_items.';
COMMENT ON COLUMN products.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN products.category_id IS 'Categoría del producto.';
COMMENT ON COLUMN products.barcode IS 'Código de barras EAN/UPC; NULL para productos a granel o sin empaque. Único cuando existe (índice parcial).';
COMMENT ON COLUMN products.name IS 'Nombre del producto como se busca y aparece en el ticket; indexado por trigramas para autocompletar.';
COMMENT ON COLUMN products.unit_type IS 'Unidad de venta; KG/G/L/ML/M habilitan cantidad fraccionada digitada desde la balanza.';
COMMENT ON COLUMN products.sale_price_cents IS 'Precio de venta vigente por unidad de medida, en céntimos de sol (p. ej. KG → céntimos por kilo).';
COMMENT ON COLUMN products.cost_cents IS 'Costo de referencia por unidad para estimar margen; el costo real histórico vive en purchase_items. NULL si aún no se conoce.';
COMMENT ON COLUMN products.min_stock IS 'Umbral de alerta de stock bajo (en la unidad del producto); 0 = sin alerta.';
COMMENT ON COLUMN products.is_active IS 'false = producto descontinuado: no aparece en el POS pero conserva historial (soft delete).';
COMMENT ON COLUMN products.updated_seq IS 'Posición en el reloj lógico de sync para el pull incremental del POS (catálogo y precios).';
COMMENT ON COLUMN products.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN products.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


-- =============================================================================
-- 4. CLIENTES
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
    'Clientes identificados. La venta normal es anónima (no se fía); solo se registra un cliente cuando pide comprobante con sus datos — hoy nota de venta nominada, mañana boleta/factura.';
COMMENT ON COLUMN customers.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN customers.doc_type IS 'Tipo de documento: DNI (persona) o RUC (empresa).';
COMMENT ON COLUMN customers.doc_number IS 'Número de documento; formato validado por CHECK (DNI 8 dígitos, RUC 11). Único junto con doc_type.';
COMMENT ON COLUMN customers.name IS 'Nombre completo o razón social, según el tipo de documento.';
COMMENT ON COLUMN customers.address IS 'Dirección fiscal o de contacto; requerida recién para FACTURA (se valida en la aplicación).';
COMMENT ON COLUMN customers.email IS 'Correo para enviar comprobantes electrónicos (futuro PSE); opcional.';
COMMENT ON COLUMN customers.phone IS 'Teléfono de contacto; opcional.';
COMMENT ON COLUMN customers.updated_seq IS 'Posición en el reloj lógico de sync; el POS descarga clientes para emitir comprobantes offline.';
COMMENT ON COLUMN customers.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN customers.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


-- =============================================================================
-- 5. VENTAS
-- =============================================================================

CREATE TABLE sales (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    branch_id       uuid        NOT NULL,
    terminal_id     uuid        NOT NULL,
    cash_session_id uuid        NOT NULL,
    user_id         uuid        NOT NULL,
    customer_id     uuid        NULL,
    status          sale_status NOT NULL DEFAULT 'COMPLETADA',
    local_number    bigint      NOT NULL,
    sold_at         timestamptz NOT NULL,
    sold_on_local   date        NOT NULL,
    subtotal_cents  bigint      NOT NULL,
    discount_cents  bigint      NOT NULL DEFAULT 0,
    total_cents     bigint      NOT NULL,
    voided_at       timestamptz NULL,
    voided_by       uuid        NULL,
    void_reason     text        NULL,
    received_at     timestamptz NOT NULL DEFAULT now(),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_sales PRIMARY KEY (id),
    CONSTRAINT ck_sales__amounts_non_negative CHECK (
        subtotal_cents >= 0 AND discount_cents >= 0 AND total_cents >= 0
    ),
    CONSTRAINT ck_sales__total_consistent CHECK (total_cents = subtotal_cents - discount_cents),
    CONSTRAINT ck_sales__local_number_positive CHECK (local_number > 0),
    CONSTRAINT ck_sales__void_coherence CHECK (
        (status = 'COMPLETADA' AND voided_at IS NULL AND voided_by IS NULL AND void_reason IS NULL)
        OR (status = 'ANULADA' AND voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL)
    )
);

COMMENT ON TABLE sales IS
    'Ventas registradas en las terminales POS. El id lo genera la terminal (UUIDv7 local, la venta nace offline) y llega al servidor por sync push idempotente. Nunca se edita ni borra: anular marca ANULADA y revierte stock con movimientos ANULACION_VENTA.';
COMMENT ON COLUMN sales.id IS 'Identificador único (UUIDv7) generado por la terminal al momento de vender, sin depender de la red.';
COMMENT ON COLUMN sales.branch_id IS 'Sucursal donde ocurrió la venta.';
COMMENT ON COLUMN sales.terminal_id IS 'Terminal que registró la venta.';
COMMENT ON COLUMN sales.cash_session_id IS 'Sesión de caja abierta bajo la cual se cobró; toda venta exige caja abierta.';
COMMENT ON COLUMN sales.user_id IS 'Cajero que realizó la venta (login por PIN en el POS).';
COMMENT ON COLUMN sales.customer_id IS 'Cliente identificado; NULL = venta anónima (el caso normal).';
COMMENT ON COLUMN sales.status IS 'COMPLETADA o ANULADA; la anulación conserva todo el registro.';
COMMENT ON COLUMN sales.local_number IS 'Correlativo local de la terminal (1, 2, 3…); único por terminal. Es el número que ve el cliente en su ticket.';
COMMENT ON COLUMN sales.sold_at IS 'Momento exacto de la venta según el reloj de la terminal (timestamptz).';
COMMENT ON COLUMN sales.sold_on_local IS 'Fecha de negocio local (día de la tienda) calculada en la terminal; base de cierres y reportes diarios sin corrimientos de zona horaria.';
COMMENT ON COLUMN sales.subtotal_cents IS 'Suma de los totales de los ítems, en céntimos de sol.';
COMMENT ON COLUMN sales.discount_cents IS 'Descuento global aplicado a la venta, en céntimos; 0 si no hubo.';
COMMENT ON COLUMN sales.total_cents IS 'Total cobrado = subtotal − descuento (garantizado por CHECK). La suma de payments debe igualarlo (regla de aplicación: no expresable como CHECK entre tablas).';
COMMENT ON COLUMN sales.voided_at IS 'Momento de la anulación; NULL si la venta sigue completada.';
COMMENT ON COLUMN sales.voided_by IS 'Usuario que autorizó la anulación (exige permiso sales.void).';
COMMENT ON COLUMN sales.void_reason IS 'Motivo obligatorio de la anulación (error de cobro, cliente se retractó…).';
COMMENT ON COLUMN sales.received_at IS 'Momento en que el servidor recibió la venta vía sync; comparado con sold_at mide el atraso de sincronización.';
COMMENT ON COLUMN sales.created_at IS 'Fecha de inserción del registro en el servidor.';
COMMENT ON COLUMN sales.updated_at IS 'Fecha de última modificación (solo cambia al anular; mantenida por trigger).';


CREATE TABLE sale_items (
    id               uuid          NOT NULL DEFAULT uuidv7(),
    sale_id          uuid          NOT NULL,
    product_id       uuid          NOT NULL,
    product_name     text          NOT NULL,
    unit_type        unit_type     NOT NULL,
    quantity         numeric(10,3) NOT NULL,
    unit_price_cents bigint        NOT NULL,
    total_cents      bigint        NOT NULL,
    created_at       timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_sale_items PRIMARY KEY (id),
    CONSTRAINT ck_sale_items__quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_sale_items__prices_non_negative CHECK (unit_price_cents >= 0 AND total_cents >= 0)
);

COMMENT ON TABLE sale_items IS
    'Líneas de una venta. Congelan nombre, unidad y precio del producto al momento de vender (snapshot): la venta es un hecho histórico que no cambia aunque el producto se renombre o cambie de precio. Inmutable.';
COMMENT ON COLUMN sale_items.id IS 'Identificador único (UUIDv7) generado por la terminal.';
COMMENT ON COLUMN sale_items.sale_id IS 'Venta a la que pertenece la línea.';
COMMENT ON COLUMN sale_items.product_id IS 'Producto vendido (referencia al catálogo vigente).';
COMMENT ON COLUMN sale_items.product_name IS 'Nombre del producto al momento de la venta (snapshot para tickets y reportes históricos).';
COMMENT ON COLUMN sale_items.unit_type IS 'Unidad de venta al momento de la venta (snapshot).';
COMMENT ON COLUMN sale_items.quantity IS 'Cantidad vendida en la unidad del producto; admite fracciones para granel (0.250 kg).';
COMMENT ON COLUMN sale_items.unit_price_cents IS 'Precio unitario cobrado, en céntimos (snapshot del precio vigente al vender).';
COMMENT ON COLUMN sale_items.total_cents IS 'Total de la línea en céntimos: cantidad × precio unitario, redondeado por la aplicación (el redondeo de granel se define en un solo lugar).';
COMMENT ON COLUMN sale_items.created_at IS 'Fecha de inserción del registro en el servidor.';


CREATE TABLE payments (
    id           uuid           NOT NULL DEFAULT uuidv7(),
    sale_id      uuid           NOT NULL,
    method       payment_method NOT NULL,
    amount_cents bigint         NOT NULL,
    reference    text           NULL,
    created_at   timestamptz    NOT NULL DEFAULT now(),

    CONSTRAINT pk_payments PRIMARY KEY (id),
    CONSTRAINT ck_payments__amount_positive CHECK (amount_cents > 0)
);

COMMENT ON TABLE payments IS
    'Pagos de una venta. Admite pago dividido (parte efectivo, parte Yape). La suma de pagos debe igualar el total de la venta (regla de aplicación). Solo los pagos EFECTIVO cuentan para el arqueo de caja. Inmutable.';
COMMENT ON COLUMN payments.id IS 'Identificador único (UUIDv7) generado por la terminal.';
COMMENT ON COLUMN payments.sale_id IS 'Venta que se está pagando.';
COMMENT ON COLUMN payments.method IS 'Método de pago: EFECTIVO, YAPE o PLIN.';
COMMENT ON COLUMN payments.amount_cents IS 'Monto pagado con este método, en céntimos de sol; siempre positivo.';
COMMENT ON COLUMN payments.reference IS 'Número de operación de Yape/Plin digitado por el cajero; NULL para efectivo.';
COMMENT ON COLUMN payments.created_at IS 'Fecha de inserción del registro en el servidor.';


CREATE TABLE sale_documents (
    id         uuid          NOT NULL DEFAULT uuidv7(),
    sale_id    uuid          NOT NULL,
    doc_type   document_type NOT NULL,
    series     text          NOT NULL,
    number     bigint        NOT NULL,
    issued_at  timestamptz   NOT NULL,
    created_at timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_sale_documents PRIMARY KEY (id),
    CONSTRAINT ck_sale_documents__number_positive CHECK (number > 0)
);

COMMENT ON TABLE sale_documents IS
    'Comprobantes emitidos por venta. Hoy solo NOTA_VENTA; la estructura ya soporta BOLETA/FACTURA para la formalización (los campos SUNAT/PSE se agregarán de forma aditiva). Una venta tiene exactamente un comprobante.';
COMMENT ON COLUMN sale_documents.id IS 'Identificador único (UUIDv7) generado por la terminal.';
COMMENT ON COLUMN sale_documents.sale_id IS 'Venta que respalda este comprobante.';
COMMENT ON COLUMN sale_documents.doc_type IS 'Tipo de comprobante emitido.';
COMMENT ON COLUMN sale_documents.series IS 'Serie del comprobante. Para NOTA_VENTA es el código de la terminal (T01): cada terminal numera su propia serie offline sin chocar con otras.';
COMMENT ON COLUMN sale_documents.number IS 'Número correlativo dentro de la serie; único junto con doc_type y series.';
COMMENT ON COLUMN sale_documents.issued_at IS 'Momento de emisión del comprobante (normalmente el de la venta).';
COMMENT ON COLUMN sale_documents.created_at IS 'Fecha de inserción del registro en el servidor.';


-- =============================================================================
-- 6. INVENTARIO
-- =============================================================================

CREATE TABLE stock_movements (
    id               uuid          NOT NULL DEFAULT uuidv7(),
    branch_id        uuid          NOT NULL,
    product_id       uuid          NOT NULL,
    type             movement_type NOT NULL,
    quantity         numeric(10,3) NOT NULL,
    sale_item_id     uuid          NULL,
    purchase_item_id uuid          NULL,
    user_id          uuid          NOT NULL,
    reason           text          NULL,
    created_at       timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_stock_movements PRIMARY KEY (id),
    CONSTRAINT ck_stock_movements__sign_by_type CHECK (
        (type IN ('VENTA', 'MERMA') AND quantity < 0)
        OR (type IN ('ANULACION_VENTA', 'COMPRA') AND quantity > 0)
        OR (type = 'AJUSTE' AND quantity <> 0)
    ),
    CONSTRAINT ck_stock_movements__reason_required CHECK (
        type NOT IN ('AJUSTE', 'MERMA') OR reason IS NOT NULL
    ),
    CONSTRAINT ck_stock_movements__source_reference CHECK (
        (type IN ('VENTA', 'ANULACION_VENTA') AND sale_item_id IS NOT NULL AND purchase_item_id IS NULL)
        OR (type = 'COMPRA' AND purchase_item_id IS NOT NULL AND sale_item_id IS NULL)
        OR (type IN ('AJUSTE', 'MERMA') AND sale_item_id IS NULL AND purchase_item_id IS NULL)
    )
);

COMMENT ON TABLE stock_movements IS
    'Libro mayor de inventario (ledger). El stock actual de un producto en una sucursal es SUM(quantity) — ver vista stock_levels. Nunca se edita ni borra: los errores se corrigen con un movimiento AJUSTE tras conteo físico.';
COMMENT ON COLUMN stock_movements.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN stock_movements.branch_id IS 'Sucursal cuyo inventario afecta el movimiento.';
COMMENT ON COLUMN stock_movements.product_id IS 'Producto afectado.';
COMMENT ON COLUMN stock_movements.type IS 'Naturaleza del movimiento; determina el signo permitido de quantity (CHECK).';
COMMENT ON COLUMN stock_movements.quantity IS 'Delta de stock con signo, en la unidad del producto: negativo saca (VENTA, MERMA), positivo ingresa (COMPRA, ANULACION_VENTA), AJUSTE lleva el signo de la corrección.';
COMMENT ON COLUMN stock_movements.sale_item_id IS 'Línea de venta que originó el movimiento (obligatoria en VENTA y ANULACION_VENTA); trazabilidad completa.';
COMMENT ON COLUMN stock_movements.purchase_item_id IS 'Línea de compra que originó el movimiento (obligatoria en COMPRA); trazabilidad completa.';
COMMENT ON COLUMN stock_movements.user_id IS 'Usuario responsable: el cajero de la venta o quien registró el ajuste/merma/compra.';
COMMENT ON COLUMN stock_movements.reason IS 'Motivo del movimiento; obligatorio en AJUSTE y MERMA (p. ej. "conteo mensual", "vencido").';
COMMENT ON COLUMN stock_movements.created_at IS 'Momento del movimiento.';


-- =============================================================================
-- 7. CAJA
-- =============================================================================

CREATE TABLE cash_sessions (
    id               uuid        NOT NULL DEFAULT uuidv7(),
    branch_id        uuid        NOT NULL,
    terminal_id      uuid        NOT NULL,
    opened_by        uuid        NOT NULL,
    opened_at        timestamptz NOT NULL,
    opening_cents    bigint      NOT NULL,
    closed_by        uuid        NULL,
    closed_at        timestamptz NULL,
    expected_cents   bigint      NULL,
    counted_cents    bigint      NULL,
    difference_cents bigint      NULL,
    closing_note     text        NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_cash_sessions PRIMARY KEY (id),
    CONSTRAINT ck_cash_sessions__opening_non_negative CHECK (opening_cents >= 0),
    CONSTRAINT ck_cash_sessions__close_coherence CHECK (
        (closed_at IS NULL AND closed_by IS NULL AND expected_cents IS NULL
            AND counted_cents IS NULL AND difference_cents IS NULL)
        OR (closed_at IS NOT NULL AND closed_by IS NOT NULL AND expected_cents IS NOT NULL
            AND counted_cents IS NOT NULL AND difference_cents IS NOT NULL
            AND closed_at > opened_at)
    ),
    CONSTRAINT ck_cash_sessions__difference_consistent CHECK (
        difference_cents IS NULL OR difference_cents = counted_cents - expected_cents
    )
);

COMMENT ON TABLE cash_sessions IS
    'Sesiones de caja (turnos) por terminal: apertura con monto inicial, ventas y movimientos durante el turno, cierre con arqueo. Esperado = apertura + Σ pagos EFECTIVO de ventas COMPLETADAS + Σ INGRESO − Σ RETIRO. Solo puede haber una sesión abierta por terminal (índice parcial).';
COMMENT ON COLUMN cash_sessions.id IS 'Identificador único (UUIDv7) generado por la terminal (la caja se abre offline).';
COMMENT ON COLUMN cash_sessions.branch_id IS 'Sucursal de la caja.';
COMMENT ON COLUMN cash_sessions.terminal_id IS 'Terminal donde se abrió la sesión.';
COMMENT ON COLUMN cash_sessions.opened_by IS 'Usuario que abrió la caja.';
COMMENT ON COLUMN cash_sessions.opened_at IS 'Momento de apertura según la terminal.';
COMMENT ON COLUMN cash_sessions.opening_cents IS 'Efectivo inicial declarado al abrir (sencillo para el vuelto), en céntimos.';
COMMENT ON COLUMN cash_sessions.closed_by IS 'Usuario que cerró la caja; NULL mientras esté abierta.';
COMMENT ON COLUMN cash_sessions.closed_at IS 'Momento de cierre; NULL = sesión abierta.';
COMMENT ON COLUMN cash_sessions.expected_cents IS 'Efectivo que debería haber al cierre según la fórmula del arqueo (snapshot calculado al cerrar).';
COMMENT ON COLUMN cash_sessions.counted_cents IS 'Efectivo contado físicamente por el cajero al cerrar.';
COMMENT ON COLUMN cash_sessions.difference_cents IS 'Descuadre = contado − esperado (CHECK); negativo = falta plata, positivo = sobra.';
COMMENT ON COLUMN cash_sessions.closing_note IS 'Observación libre del cierre (explicación del descuadre, incidencias).';
COMMENT ON COLUMN cash_sessions.created_at IS 'Fecha de inserción del registro en el servidor.';
COMMENT ON COLUMN cash_sessions.updated_at IS 'Fecha de última modificación (cambia al cerrar; mantenida por trigger).';


CREATE TABLE cash_movements (
    id              uuid               NOT NULL DEFAULT uuidv7(),
    cash_session_id uuid               NOT NULL,
    type            cash_movement_type NOT NULL,
    amount_cents    bigint             NOT NULL,
    reason          text               NOT NULL,
    user_id         uuid               NOT NULL,
    created_at      timestamptz        NOT NULL DEFAULT now(),

    CONSTRAINT pk_cash_movements PRIMARY KEY (id),
    CONSTRAINT ck_cash_movements__amount_positive CHECK (amount_cents > 0)
);

COMMENT ON TABLE cash_movements IS
    'Movimientos manuales de efectivo dentro de una sesión de caja (ingresos y retiros con motivo). Las ventas NO van aquí: entran al arqueo vía payments. Inmutable: un error se corrige con el movimiento contrario.';
COMMENT ON COLUMN cash_movements.id IS 'Identificador único (UUIDv7) generado por la terminal.';
COMMENT ON COLUMN cash_movements.cash_session_id IS 'Sesión de caja afectada.';
COMMENT ON COLUMN cash_movements.type IS 'INGRESO suma al efectivo esperado; RETIRO resta.';
COMMENT ON COLUMN cash_movements.amount_cents IS 'Monto del movimiento en céntimos; siempre positivo (el sentido lo da type).';
COMMENT ON COLUMN cash_movements.reason IS 'Motivo obligatorio (p. ej. "pago a proveedor", "retiro de la dueña").';
COMMENT ON COLUMN cash_movements.user_id IS 'Usuario que registró el movimiento.';
COMMENT ON COLUMN cash_movements.created_at IS 'Momento del movimiento.';


-- =============================================================================
-- 8. COMPRAS
-- =============================================================================

CREATE TABLE suppliers (
    id         uuid        NOT NULL DEFAULT uuidv7(),
    name       text        NOT NULL,
    ruc        text        NULL,
    phone      text        NULL,
    address    text        NULL,
    is_active  boolean     NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_suppliers PRIMARY KEY (id),
    CONSTRAINT ck_suppliers__ruc_format CHECK (ruc IS NULL OR ruc ~ '^[0-9]{11}$')
);

COMMENT ON TABLE suppliers IS
    'Proveedores: distribuidoras de Piura (Alvarez Bohl, Kompass…) y, opcionalmente, puestos frecuentes del mercado mayorista.';
COMMENT ON COLUMN suppliers.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN suppliers.name IS 'Nombre comercial del proveedor.';
COMMENT ON COLUMN suppliers.ruc IS 'RUC del proveedor (11 dígitos); único cuando existe. NULL para puestos informales del mayorista.';
COMMENT ON COLUMN suppliers.phone IS 'Teléfono para hacer pedidos; opcional.';
COMMENT ON COLUMN suppliers.address IS 'Dirección del proveedor; opcional.';
COMMENT ON COLUMN suppliers.is_active IS 'false = ya no se le compra; se conserva por el historial de compras.';
COMMENT ON COLUMN suppliers.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN suppliers.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE purchases (
    id          uuid            NOT NULL DEFAULT uuidv7(),
    branch_id   uuid            NOT NULL,
    supplier_id uuid            NULL,
    kind        purchase_kind   NOT NULL,
    status      purchase_status NOT NULL,
    ordered_at  timestamptz     NULL,
    received_at timestamptz     NULL,
    total_cents bigint          NOT NULL DEFAULT 0,
    note        text            NULL,
    created_by  uuid            NOT NULL,
    created_at  timestamptz     NOT NULL DEFAULT now(),
    updated_at  timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT pk_purchases PRIMARY KEY (id),
    CONSTRAINT ck_purchases__total_non_negative CHECK (total_cents >= 0),
    CONSTRAINT ck_purchases__distribuidora_requires_supplier CHECK (
        kind <> 'DISTRIBUIDORA' OR supplier_id IS NOT NULL
    ),
    CONSTRAINT ck_purchases__mayorista_born_received CHECK (
        kind <> 'MAYORISTA' OR status = 'RECIBIDA'
    ),
    CONSTRAINT ck_purchases__status_dates CHECK (
        (status = 'PEDIDA' AND received_at IS NULL)
        OR (status = 'RECIBIDA' AND received_at IS NOT NULL)
        OR (status = 'CANCELADA' AND received_at IS NULL)
    ),
    CONSTRAINT ck_purchases__distribuidora_requires_ordered_at CHECK (
        kind <> 'DISTRIBUIDORA' OR ordered_at IS NOT NULL
    )
);

COMMENT ON TABLE purchases IS
    'Compras de mercadería. MAYORISTA: se compra y recibe en el acto (nace RECIBIDA, proveedor opcional). DISTRIBUIDORA: pedido que llega días después (PEDIDA → RECIBIDA | CANCELADA, proveedor obligatorio). Pasar a RECIBIDA genera los movimientos de stock COMPRA.';
COMMENT ON COLUMN purchases.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN purchases.branch_id IS 'Sucursal que recibe la mercadería.';
COMMENT ON COLUMN purchases.supplier_id IS 'Proveedor; obligatorio para DISTRIBUIDORA (CHECK), opcional para MAYORISTA.';
COMMENT ON COLUMN purchases.kind IS 'Modalidad de compra: MAYORISTA o DISTRIBUIDORA; define el ciclo de estados permitido.';
COMMENT ON COLUMN purchases.status IS 'Estado del ciclo de vida; solo el paso a RECIBIDA ingresa stock.';
COMMENT ON COLUMN purchases.ordered_at IS 'Fecha del pedido; obligatoria para DISTRIBUIDORA, NULL para MAYORISTA (no hay pedido previo).';
COMMENT ON COLUMN purchases.received_at IS 'Fecha de recepción de la mercadería; NOT NULL exactamente cuando status = RECIBIDA (CHECK).';
COMMENT ON COLUMN purchases.total_cents IS 'Costo total de la compra en céntimos; mantenido por la aplicación como suma de purchase_items.';
COMMENT ON COLUMN purchases.note IS 'Observación libre (condiciones, faltantes, motivo de cancelación).';
COMMENT ON COLUMN purchases.created_by IS 'Usuario que registró la compra.';
COMMENT ON COLUMN purchases.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN purchases.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE purchase_items (
    id              uuid          NOT NULL DEFAULT uuidv7(),
    purchase_id     uuid          NOT NULL,
    product_id      uuid          NOT NULL,
    quantity        numeric(10,3) NOT NULL,
    unit_cost_cents bigint        NOT NULL,
    total_cents     bigint        NOT NULL,
    created_at      timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_purchase_items PRIMARY KEY (id),
    CONSTRAINT ck_purchase_items__quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_purchase_items__costs_non_negative CHECK (unit_cost_cents >= 0 AND total_cents >= 0)
);

COMMENT ON TABLE purchase_items IS
    'Líneas de una compra: qué productos, cuánto y a qué costo. Es la fuente del costo real histórico (products.cost_cents es solo referencia vigente).';
COMMENT ON COLUMN purchase_items.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN purchase_items.purchase_id IS 'Compra a la que pertenece la línea.';
COMMENT ON COLUMN purchase_items.product_id IS 'Producto comprado.';
COMMENT ON COLUMN purchase_items.quantity IS 'Cantidad comprada en la unidad del producto; admite fracciones (25.500 kg).';
COMMENT ON COLUMN purchase_items.unit_cost_cents IS 'Costo unitario pagado, en céntimos.';
COMMENT ON COLUMN purchase_items.total_cents IS 'Costo total de la línea en céntimos: cantidad × costo unitario, redondeado por la aplicación.';
COMMENT ON COLUMN purchase_items.created_at IS 'Fecha de creación del registro.';


-- =============================================================================
-- 9. SINCRONIZACIÓN
-- =============================================================================

CREATE TABLE sync_ingest_log (
    id          uuid        NOT NULL DEFAULT uuidv7(),
    terminal_id uuid        NOT NULL,
    event_id    uuid        NOT NULL,
    event_type  text        NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_sync_ingest_log PRIMARY KEY (id)
);

COMMENT ON TABLE sync_ingest_log IS
    'Registro de eventos recibidos por sync push; garantiza idempotencia. La terminal reenvía hasta recibir confirmación: si el event_id ya está aquí, el evento se confirma sin re-aplicarse (deduplicación).';
COMMENT ON COLUMN sync_ingest_log.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN sync_ingest_log.terminal_id IS 'Terminal que envió el evento.';
COMMENT ON COLUMN sync_ingest_log.event_id IS 'Identificador del evento generado por la terminal (UUIDv7, viene del outbox local); único global — es la clave de deduplicación.';
COMMENT ON COLUMN sync_ingest_log.event_type IS 'Tipo de evento aplicado (p. ej. sale.created, cash_session.closed); útil para auditoría y depuración.';
COMMENT ON COLUMN sync_ingest_log.received_at IS 'Momento en que el servidor recibió y aplicó el evento.';


-- =============================================================================
-- RELACIONES (claves foráneas)
-- Todas al final, separadas de la definición de tablas (convención del
-- proyecto para leer el panorama completo). ON DELETE RESTRICT por regla:
-- nada operativo se borra en cascada; la única excepción documentada es la
-- cadena de rotación de refresh_tokens (SET NULL).
-- =============================================================================

-- --- 1. Organización e identidad -------------------------------------------

ALTER TABLE user_roles
    ADD CONSTRAINT fk_user_roles__user_id
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_user_roles__role_id
        FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_user_roles__branch_id
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE RESTRICT;

ALTER TABLE role_permissions
    ADD CONSTRAINT fk_role_permissions__role_id
        FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_role_permissions__permission_id
        FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE RESTRICT;

ALTER TABLE refresh_tokens
    ADD CONSTRAINT fk_refresh_tokens__user_id
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_refresh_tokens__replaced_by_id
        FOREIGN KEY (replaced_by_id) REFERENCES refresh_tokens (id) ON DELETE SET NULL;

-- --- 2. Terminales -----------------------------------------------------------

ALTER TABLE terminals
    ADD CONSTRAINT fk_terminals__branch_id
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE RESTRICT;

ALTER TABLE terminal_enrollment_codes
    ADD CONSTRAINT fk_terminal_enrollment_codes__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_terminal_enrollment_codes__created_by
        FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE terminal_credentials
    ADD CONSTRAINT fk_terminal_credentials__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals (id) ON DELETE RESTRICT;

-- --- 3. Catálogo -------------------------------------------------------------

ALTER TABLE products
    ADD CONSTRAINT fk_products__category_id
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT;

-- --- 5. Ventas ---------------------------------------------------------------

ALTER TABLE sales
    ADD CONSTRAINT fk_sales__branch_id
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__cash_session_id
        FOREIGN KEY (cash_session_id) REFERENCES cash_sessions (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__user_id
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__customer_id
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__voided_by
        FOREIGN KEY (voided_by) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE sale_items
    ADD CONSTRAINT fk_sale_items__sale_id
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sale_items__product_id
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT;

ALTER TABLE payments
    ADD CONSTRAINT fk_payments__sale_id
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE RESTRICT;

ALTER TABLE sale_documents
    ADD CONSTRAINT fk_sale_documents__sale_id
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE RESTRICT;

-- --- 6. Inventario -----------------------------------------------------------

ALTER TABLE stock_movements
    ADD CONSTRAINT fk_stock_movements__branch_id
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__product_id
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__sale_item_id
        FOREIGN KEY (sale_item_id) REFERENCES sale_items (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__purchase_item_id
        FOREIGN KEY (purchase_item_id) REFERENCES purchase_items (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__user_id
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT;

-- --- 7. Caja -----------------------------------------------------------------

ALTER TABLE cash_sessions
    ADD CONSTRAINT fk_cash_sessions__branch_id
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cash_sessions__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cash_sessions__opened_by
        FOREIGN KEY (opened_by) REFERENCES users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cash_sessions__closed_by
        FOREIGN KEY (closed_by) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE cash_movements
    ADD CONSTRAINT fk_cash_movements__cash_session_id
        FOREIGN KEY (cash_session_id) REFERENCES cash_sessions (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cash_movements__user_id
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT;

-- --- 8. Compras --------------------------------------------------------------

ALTER TABLE purchases
    ADD CONSTRAINT fk_purchases__branch_id
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_purchases__supplier_id
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_purchases__created_by
        FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE purchase_items
    ADD CONSTRAINT fk_purchase_items__purchase_id
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_purchase_items__product_id
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT;

-- --- 9. Sincronización -------------------------------------------------------

ALTER TABLE sync_ingest_log
    ADD CONSTRAINT fk_sync_ingest_log__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals (id) ON DELETE RESTRICT;
