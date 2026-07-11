-- =============================================================================
-- tables/07_inventory.sql — Inventario: kardex (ledger) y conteos físicos.
-- El stock NUNCA es un saldo editable: es SUM(stock_movements.quantity) por
-- (almacén, producto) — vista stock_levels. Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE inventory.stock_movements (
    id                      uuid          NOT NULL DEFAULT uuidv7(),
    warehouse_id            uuid          NOT NULL,
    product_id              uuid          NOT NULL,
    type                    inventory.movement_type NOT NULL,
    quantity                numeric(10,3) NOT NULL,
    sale_item_id            uuid          NULL,
    purchase_item_id        uuid          NULL,
    inventory_count_item_id uuid          NULL,
    user_id                 uuid          NOT NULL,
    reason                  text          NULL,
    occurred_at             timestamptz   NOT NULL,
    created_at              timestamptz   NOT NULL DEFAULT now(),

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
        (type IN ('VENTA', 'ANULACION_VENTA')
            AND sale_item_id IS NOT NULL AND purchase_item_id IS NULL AND inventory_count_item_id IS NULL)
        OR (type = 'COMPRA'
            AND purchase_item_id IS NOT NULL AND sale_item_id IS NULL AND inventory_count_item_id IS NULL)
        OR (type = 'MERMA'
            AND sale_item_id IS NULL AND purchase_item_id IS NULL AND inventory_count_item_id IS NULL)
        OR (type = 'AJUSTE'
            AND sale_item_id IS NULL AND purchase_item_id IS NULL)
    )
);

COMMENT ON TABLE inventory.stock_movements IS
    'Libro mayor de inventario (kardex). El stock actual de un producto en un almacén es SUM(quantity) — ver vista stock_levels. Las cantidades van SIEMPRE en la unidad base del producto (vender un six-pack registra −6). Nunca se edita ni borra: los errores se corrigen con un movimiento AJUSTE (manual o generado por un conteo físico). Traslados entre almacenes: futuros movement_type TRASLADO_* (ADD VALUE), no UPDATE.';
COMMENT ON COLUMN inventory.stock_movements.id IS 'Identificador único (UUIDv7); lo genera la terminal cuando el movimiento nace offline (VENTA, ANULACION_VENTA, ajustes del POS).';
COMMENT ON COLUMN inventory.stock_movements.warehouse_id IS 'Almacén cuyo stock afecta el movimiento. En ventas es el almacén asignado a la sucursal (branches.warehouse_id) al momento del hecho: el POS lo resuelve de su configuración sincronizada.';
COMMENT ON COLUMN inventory.stock_movements.product_id IS 'Producto afectado.';
COMMENT ON COLUMN inventory.stock_movements.type IS 'Naturaleza del movimiento; determina el signo permitido de quantity (CHECK).';
COMMENT ON COLUMN inventory.stock_movements.quantity IS 'Delta de stock con signo, en la UNIDAD BASE del producto: negativo saca (VENTA = cantidad × factor de la presentación, MERMA), positivo ingresa (COMPRA, ANULACION_VENTA), AJUSTE lleva el signo de la corrección.';
COMMENT ON COLUMN inventory.stock_movements.sale_item_id IS 'Línea de venta que originó el movimiento (obligatoria en VENTA y ANULACION_VENTA); trazabilidad completa.';
COMMENT ON COLUMN inventory.stock_movements.purchase_item_id IS 'Línea de compra que originó el movimiento (obligatoria en COMPRA); trazabilidad completa.';
COMMENT ON COLUMN inventory.stock_movements.inventory_count_item_id IS 'Línea del conteo físico que originó este AJUSTE; NULL en ajustes manuales y en el resto de tipos (CHECK).';
COMMENT ON COLUMN inventory.stock_movements.user_id IS 'Usuario responsable: el cajero de la venta o quien registró el ajuste/merma/compra/conteo.';
COMMENT ON COLUMN inventory.stock_movements.reason IS 'Motivo del movimiento; obligatorio en AJUSTE y MERMA (p. ej. "conteo mensual", "vencido").';
COMMENT ON COLUMN inventory.stock_movements.occurred_at IS 'Momento real del movimiento según su origen (reloj de la terminal si nació offline); base del kardex. created_at solo dice cuándo lo insertó el servidor.';
COMMENT ON COLUMN inventory.stock_movements.created_at IS 'Fecha de inserción del registro en el servidor.';


CREATE TABLE inventory.inventory_counts (
    id           uuid                   NOT NULL DEFAULT uuidv7(),
    warehouse_id uuid                   NOT NULL,
    status       inventory.inventory_count_status NOT NULL DEFAULT 'EN_CURSO',
    note         text                   NULL,
    created_by   uuid                   NOT NULL,
    applied_by   uuid                   NULL,
    applied_at   timestamptz            NULL,
    cancelled_by uuid                   NULL,
    cancelled_at timestamptz            NULL,
    created_at   timestamptz            NOT NULL DEFAULT now(),
    updated_at   timestamptz            NOT NULL DEFAULT now(),

    CONSTRAINT pk_inventory_counts PRIMARY KEY (id),
    CONSTRAINT ck_inventory_counts__status_coherence CHECK (
        (status = 'EN_CURSO' AND applied_at IS NULL AND applied_by IS NULL
            AND cancelled_at IS NULL AND cancelled_by IS NULL)
        OR (status = 'APLICADO' AND applied_at IS NOT NULL AND applied_by IS NOT NULL
            AND cancelled_at IS NULL AND cancelled_by IS NULL)
        OR (status = 'CANCELADO' AND cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL
            AND applied_at IS NULL AND applied_by IS NULL)
    )
);

COMMENT ON TABLE inventory.inventory_counts IS
    'Conteos físicos de inventario (inventariado) por almacén. Proceso: se abre EN_CURSO, se registran las cantidades contadas por producto (inventory_count_items) y al APLICAR la aplicación genera — en la misma transacción — un stock_movement AJUSTE por cada diferencia contada vs esperada (delta 0 = sin movimiento). También sirve para cargar el inventario inicial de un almacén nuevo (esperado 0, contado = lo que hay). A lo sumo un conteo EN_CURSO por almacén (índice parcial).';
COMMENT ON COLUMN inventory.inventory_counts.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN inventory.inventory_counts.warehouse_id IS 'Almacén que se está contando.';
COMMENT ON COLUMN inventory.inventory_counts.status IS 'Ciclo de vida: EN_CURSO → APLICADO (genera AJUSTEs) | CANCELADO (no toca stock). CHECK de coherencia con fechas/usuarios.';
COMMENT ON COLUMN inventory.inventory_counts.note IS 'Observación libre del conteo (p. ej. "conteo mensual julio", motivo de la cancelación).';
COMMENT ON COLUMN inventory.inventory_counts.created_by IS 'Usuario que abrió el conteo.';
COMMENT ON COLUMN inventory.inventory_counts.applied_by IS 'Usuario que aplicó el conteo; NULL mientras no se aplique.';
COMMENT ON COLUMN inventory.inventory_counts.applied_at IS 'Momento de aplicación (los AJUSTE llevan este instante como occurred_at); NULL mientras no se aplique.';
COMMENT ON COLUMN inventory.inventory_counts.cancelled_by IS 'Usuario que canceló el conteo; NULL si no fue cancelado.';
COMMENT ON COLUMN inventory.inventory_counts.cancelled_at IS 'Momento de cancelación; NULL si no fue cancelado.';
COMMENT ON COLUMN inventory.inventory_counts.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN inventory.inventory_counts.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE inventory.inventory_count_items (
    id                 uuid          NOT NULL DEFAULT uuidv7(),
    inventory_count_id uuid          NOT NULL,
    product_id         uuid          NOT NULL,
    expected_qty       numeric(10,3) NOT NULL,
    counted_qty        numeric(10,3) NOT NULL,
    note               text          NULL,
    created_at         timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_inventory_count_items PRIMARY KEY (id),
    CONSTRAINT ck_inventory_count_items__counted_non_negative CHECK (counted_qty >= 0)
);

COMMENT ON TABLE inventory.inventory_count_items IS
    'Líneas de un conteo físico: qué se esperaba vs qué se contó, por producto, en unidad base. La diferencia (contado − esperado) es el AJUSTE que se genera al aplicar el conteo; el snapshot de expected_qty deja auditable contra qué stock se comparó.';
COMMENT ON COLUMN inventory.inventory_count_items.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN inventory.inventory_count_items.inventory_count_id IS 'Conteo al que pertenece la línea.';
COMMENT ON COLUMN inventory.inventory_count_items.product_id IS 'Producto contado; único por conteo (índice ux).';
COMMENT ON COLUMN inventory.inventory_count_items.expected_qty IS 'Stock esperado según el kardex al momento de registrar la línea (snapshot, unidad base); puede ser negativo si el ledger estaba descuadrado.';
COMMENT ON COLUMN inventory.inventory_count_items.counted_qty IS 'Cantidad física contada (unidad base); nunca negativa (CHECK).';
COMMENT ON COLUMN inventory.inventory_count_items.note IS 'Observación de la línea (p. ej. "cajas mojadas al fondo"); opcional.';
COMMENT ON COLUMN inventory.inventory_count_items.created_at IS 'Fecha de creación del registro.';
