-- =============================================================================
-- tables/01_organization.sql — Configuración del negocio y organización física.
-- Convenciones generales del DDL: ver tables/README dentro de database/README.md
-- y PROYECTO.md § 6. Las FK de TODOS los dominios viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE org.business_settings (
    id             boolean       NOT NULL DEFAULT true,
    trade_name     text          NOT NULL,
    legal_name     text          NULL,
    ruc            text          NULL,
    igv_rate_pct   numeric(5,2)  NOT NULL DEFAULT 18.00,
    icbper_cents   bigint        NOT NULL DEFAULT 50,
    is_formalized  boolean       NOT NULL DEFAULT false,
    receipt_footer text          NULL,
    updated_seq    bigint        NOT NULL DEFAULT nextval('sync.sync_seq'),
    created_at     timestamptz   NOT NULL DEFAULT now(),
    updated_at     timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_business_settings PRIMARY KEY (id),
    CONSTRAINT ck_business_settings__singleton CHECK (id = true),
    CONSTRAINT ck_business_settings__ruc_format CHECK (ruc IS NULL OR ruc ~ '^[0-9]{11}$'),
    CONSTRAINT ck_business_settings__igv_rate_range CHECK (igv_rate_pct >= 0 AND igv_rate_pct <= 100),
    CONSTRAINT ck_business_settings__icbper_non_negative CHECK (icbper_cents >= 0),
    CONSTRAINT ck_business_settings__formal_requires_ruc CHECK (NOT is_formalized OR ruc IS NOT NULL)
);

COMMENT ON TABLE org.business_settings IS
    'Configuración global del negocio (fila única, sembrada por seeds/system.sql). Excepción documentada a la regla de PK uuid: es un singleton — id boolean true + CHECK garantizan una sola fila. El POS la descarga por pull (cabecera del ticket, tasas de impuestos, estado de formalización).';
COMMENT ON COLUMN org.business_settings.id IS 'Siempre true: PK del singleton; el CHECK impide una segunda fila.';
COMMENT ON COLUMN org.business_settings.trade_name IS 'Nombre comercial del negocio, como aparece en la cabecera de los tickets.';
COMMENT ON COLUMN org.business_settings.legal_name IS 'Razón social registrada en SUNAT; NULL mientras el negocio sea informal.';
COMMENT ON COLUMN org.business_settings.ruc IS 'RUC del negocio (11 dígitos); NULL mientras sea informal. Obligatorio para marcar is_formalized (CHECK).';
COMMENT ON COLUMN org.business_settings.igv_rate_pct IS 'Tasa de IGV vigente en porcentaje (18.00). Solo se aplica cuando is_formalized = true; el impuesto va contenido en el precio final, nunca se suma encima.';
COMMENT ON COLUMN org.business_settings.icbper_cents IS 'ICBPER vigente en céntimos por bolsa plástica (Ley 30884: S/ 0.50 desde 2023). Igual que el IGV es latente: mientras is_formalized = false los snapshots de venta van en 0; al formalizar, cada bolsa vendida (products.icbper_applies) suma este monto por unidad ENCIMA del precio (único tributo que sí se suma, y no integra la base del IGV).';
COMMENT ON COLUMN org.business_settings.is_formalized IS 'false = negocio informal: toda venta se registra con impuestos 0 (IGV e ICBPER) y emite NOTA_VENTA. true = calcular IGV contenido e ICBPER por línea y habilitar BOLETA/FACTURA vía PSE (F3).';
COMMENT ON COLUMN org.business_settings.receipt_footer IS 'Texto libre al pie del ticket (p. ej. "¡Gracias por su compra!"); NULL = sin pie.';
COMMENT ON COLUMN org.business_settings.updated_seq IS 'Posición en el reloj lógico de sync; el POS descarga cambios de configuración por pull.';
COMMENT ON COLUMN org.business_settings.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN org.business_settings.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE org.warehouses (
    id          uuid        NOT NULL DEFAULT uuidv7(),
    code        text        NOT NULL,
    name        text        NOT NULL,
    is_active   boolean     NOT NULL DEFAULT true,
    updated_seq bigint      NOT NULL DEFAULT nextval('sync.sync_seq'),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_warehouses PRIMARY KEY (id)
);

COMMENT ON TABLE org.warehouses IS
    'Almacenes físicos, entidad de primera clase: TODO el stock cuelga de un almacén (stock_movements, purchases, inventory_counts), nunca de la sucursal directo. La relación con sucursales es al revés de lo intuitivo: branches.warehouse_id apunta aquí (toda sucursal EXIGE un almacén; varias sucursales pueden compartir uno). Un almacén sin sucursales que lo apunten es un depósito puro (futuro almacén central); habilitar traslados será agregar movement_type TRASLADO_* (ADD VALUE), sin migrar nada.';
COMMENT ON COLUMN org.warehouses.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN org.warehouses.code IS 'Código corto único global (p. ej. ALM-01); aparece en kardex y reportes.';
COMMENT ON COLUMN org.warehouses.name IS 'Nombre descriptivo (p. ej. "Almacén tienda Centro").';
COMMENT ON COLUMN org.warehouses.is_active IS 'false = almacén cerrado; se conserva porque el ledger histórico lo referencia. La aplicación impide desactivar un almacén mientras alguna sucursal activa lo use.';
COMMENT ON COLUMN org.warehouses.updated_seq IS 'Posición en el reloj lógico de sync; el POS descarga el almacén de su sucursal por pull.';
COMMENT ON COLUMN org.warehouses.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN org.warehouses.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE org.branches (
    id           uuid        NOT NULL DEFAULT uuidv7(),
    code         text        NOT NULL,
    name         text        NOT NULL,
    address      text        NULL,
    phone        text        NULL,
    warehouse_id uuid        NOT NULL,
    is_active    boolean     NOT NULL DEFAULT true,
    updated_seq  bigint      NOT NULL DEFAULT nextval('sync.sync_seq'),
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_branches PRIMARY KEY (id)
);

COMMENT ON TABLE org.branches IS
    'Sucursales (tiendas físicas) de la cadena. Todo lo operativo (ventas, caja, terminales) cuelga de una sucursal; el stock cuelga del almacén que la sucursal tiene asignado (warehouse_id NOT NULL: no existe sucursal sin almacén). Al crearla, el panel asigna un almacén existente o crea uno junto con ella (misma transacción en la API).';
COMMENT ON COLUMN org.branches.id IS 'Identificador único (UUIDv7, ordenable por tiempo).';
COMMENT ON COLUMN org.branches.code IS 'Código corto legible y único de la sucursal (p. ej. S01); se usa en reportes y tickets.';
COMMENT ON COLUMN org.branches.name IS 'Nombre comercial de la sucursal (p. ej. "Minimarket Los Olivos").';
COMMENT ON COLUMN org.branches.address IS 'Dirección física de la tienda; opcional.';
COMMENT ON COLUMN org.branches.phone IS 'Teléfono de contacto de la tienda; opcional.';
COMMENT ON COLUMN org.branches.warehouse_id IS 'Almacén operativo de la sucursal: sus ventas descargan stock de aquí y sus compras entran aquí salvo indicación contraria. Varias sucursales pueden apuntar al mismo almacén (pool compartido). Reasignarlo es un cambio de configuración: los movimientos ya escritos conservan su almacén histórico.';
COMMENT ON COLUMN org.branches.is_active IS 'false = sucursal cerrada u operativamente deshabilitada; nunca se borra (soft delete).';
COMMENT ON COLUMN org.branches.updated_seq IS 'Posición en el reloj lógico de sync (secuencia sync_seq); el POS descarga cambios con updated_seq > su cursor.';
COMMENT ON COLUMN org.branches.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN org.branches.updated_at IS 'Fecha de última modificación (mantenida por trigger).';
