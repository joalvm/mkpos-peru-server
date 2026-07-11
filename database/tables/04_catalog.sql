-- =============================================================================
-- tables/04_catalog.sql — Catálogo de productos (sincroniza al POS).
--
-- Modelo en tres capas, separando conceptos que en una bodega real divergen:
--   · products               → QUÉ se vende (concepto + unidad base de stock
--                               + clasificación fiscal). El stock y el kardex
--                               viven SIEMPRE en la unidad base.
--   · product_presentations  → CÓMO se vende o compra (unidad suelta,
--                               six-pack, caja x24, docena, kilo) con su
--                               factor de conversión a unidad base y su precio.
--   · product_barcodes       → códigos escaneables (N por presentación: el
--                               six-pack trae un EAN distinto al de la caja).
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE catalog.product_categories (
    id            uuid        NOT NULL DEFAULT uuidv7(),
    name          text        NOT NULL,
    display_order integer     NOT NULL DEFAULT 0,
    is_active     boolean     NOT NULL DEFAULT true,
    updated_seq   bigint      NOT NULL DEFAULT nextval('sync.sync_seq'),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_product_categories PRIMARY KEY (id)
);

COMMENT ON TABLE catalog.product_categories IS
    'Categorías de productos (abarrotes, bebidas, limpieza…). Jerarquía plana a propósito: un minimarket no necesita árbol de categorías.';
COMMENT ON COLUMN catalog.product_categories.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN catalog.product_categories.name IS 'Nombre de la categoría; único sin distinción de mayúsculas (índice ux_product_categories__name).';
COMMENT ON COLUMN catalog.product_categories.display_order IS 'Orden de aparición en la interfaz del POS (botonera de categorías); menor = primero.';
COMMENT ON COLUMN catalog.product_categories.is_active IS 'false = categoría oculta en interfaces; no se borra porque productos históricos la referencian.';
COMMENT ON COLUMN catalog.product_categories.updated_seq IS 'Posición en el reloj lógico de sync para el pull incremental del POS.';
COMMENT ON COLUMN catalog.product_categories.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN catalog.product_categories.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE catalog.brands (
    id          uuid        NOT NULL DEFAULT uuidv7(),
    name        text        NOT NULL,
    is_active   boolean     NOT NULL DEFAULT true,
    updated_seq bigint      NOT NULL DEFAULT nextval('sync.sync_seq'),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_brands PRIMARY KEY (id)
);

COMMENT ON TABLE catalog.brands IS
    'Marcas de productos (Coca-Cola, Gloria, Costeño…). Tabla propia y no texto libre para evitar duplicados por tipeo y permitir filtrar/reportar por marca. Opcional por producto: el granel del mayorista no suele tener marca.';
COMMENT ON COLUMN catalog.brands.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN catalog.brands.name IS 'Nombre de la marca; único sin distinción de mayúsculas (índice ux_brands__name).';
COMMENT ON COLUMN catalog.brands.is_active IS 'false = marca oculta en interfaces; no se borra porque productos la referencian.';
COMMENT ON COLUMN catalog.brands.updated_seq IS 'Posición en el reloj lógico de sync para el pull incremental del POS.';
COMMENT ON COLUMN catalog.brands.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN catalog.brands.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE catalog.products (
    id              uuid            NOT NULL DEFAULT uuidv7(),
    category_id     uuid            NOT NULL,
    brand_id        uuid            NULL,
    name            text            NOT NULL,
    base_unit       catalog.unit_type       NOT NULL,
    cost_cents      bigint          NULL,
    tax_affectation catalog.tax_affectation NOT NULL DEFAULT 'GRAVADO',
    icbper_applies  boolean         NOT NULL DEFAULT false,
    is_open_price   boolean         NOT NULL DEFAULT false,
    min_stock       numeric(10,3)   NOT NULL DEFAULT 0,
    is_active       boolean         NOT NULL DEFAULT true,
    updated_seq     bigint          NOT NULL DEFAULT nextval('sync.sync_seq'),
    created_at      timestamptz     NOT NULL DEFAULT now(),
    updated_at      timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT pk_products PRIMARY KEY (id),
    CONSTRAINT ck_products__cost_non_negative CHECK (cost_cents IS NULL OR cost_cents >= 0),
    CONSTRAINT ck_products__min_stock_non_negative CHECK (min_stock >= 0)
);

COMMENT ON TABLE catalog.products IS
    'Producto conceptual: lo que se stockea y clasifica. NO tiene precio ni código de barras propios: los precios de venta viven en product_presentations (cómo se vende) y los códigos en product_barcodes. El stock y el kardex se llevan SIEMPRE en base_unit; vender un six-pack descarga 6 unidades base. Al crear un producto la aplicación crea siempre su presentación base (factor 1: "Unidad" o "Kilo") para que sea vendible de inmediato.';
COMMENT ON COLUMN catalog.products.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN catalog.products.category_id IS 'Categoría del producto.';
COMMENT ON COLUMN catalog.products.brand_id IS 'Marca del producto; NULL para granel o productos sin marca.';
COMMENT ON COLUMN catalog.products.name IS 'Nombre del producto como se busca y aparece en el ticket (p. ej. "Coca-Cola 500 ml"); indexado por trigramas para autocompletar.';
COMMENT ON COLUMN catalog.products.base_unit IS 'Unidad base de stock y kardex. KG/G/L/ML/M habilitan cantidad fraccionada (granel digitado desde balanza). Las formas de venta/compra son presentaciones con factor sobre esta unidad.';
COMMENT ON COLUMN catalog.products.cost_cents IS 'Costo de referencia por UNIDAD BASE para estimar margen; la aplicación lo recalcula al recibir compras (costo de presentación ÷ factor). El costo real histórico vive en purchase_items. NULL si aún no se conoce.';
COMMENT ON COLUMN catalog.products.tax_affectation IS 'Afectación IGV del producto (GRAVADO por defecto; EXONERADO para frutas/verduras frescas del Apéndice I). Sin efecto mientras business_settings.is_formalized = false, pero el catálogo ya nace clasificado para la formalización (F3).';
COMMENT ON COLUMN catalog.products.icbper_applies IS 'true = el producto es una bolsa plástica gravada con ICBPER (Ley 30884): al venderla se suma business_settings.icbper_cents por unidad, discriminado en el comprobante. Latente igual que el IGV: snapshot 0 mientras el negocio sea informal.';
COMMENT ON COLUMN catalog.products.is_open_price IS 'true = producto de precio abierto ("VARIOS"): el cajero digita el precio en cada venta; el precio de la presentación actúa solo como sugerencia. Para artículos sin catalogar.';
COMMENT ON COLUMN catalog.products.min_stock IS 'Umbral de alerta de stock bajo (en unidad base); 0 = sin alerta.';
COMMENT ON COLUMN catalog.products.is_active IS 'false = producto descontinuado: no aparece en el POS pero conserva historial (soft delete).';
COMMENT ON COLUMN catalog.products.updated_seq IS 'Posición en el reloj lógico de sync para el pull incremental del POS (catálogo y clasificación fiscal).';
COMMENT ON COLUMN catalog.products.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN catalog.products.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE catalog.product_presentations (
    id                  uuid          NOT NULL DEFAULT uuidv7(),
    product_id          uuid          NOT NULL,
    name                text          NOT NULL,
    factor              numeric(10,3) NOT NULL,
    price_cents         bigint        NULL,
    is_sellable         boolean       NOT NULL DEFAULT true,
    is_purchasable      boolean       NOT NULL DEFAULT false,
    is_default_sale     boolean       NOT NULL DEFAULT false,
    is_default_purchase boolean       NOT NULL DEFAULT false,
    is_active           boolean       NOT NULL DEFAULT true,
    updated_seq         bigint        NOT NULL DEFAULT nextval('sync.sync_seq'),
    created_at          timestamptz   NOT NULL DEFAULT now(),
    updated_at          timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_product_presentations PRIMARY KEY (id),
    CONSTRAINT ck_product_presentations__factor_positive CHECK (factor > 0),
    CONSTRAINT ck_product_presentations__price_non_negative CHECK (price_cents IS NULL OR price_cents >= 0),
    CONSTRAINT ck_product_presentations__sellable_or_purchasable CHECK (is_sellable OR is_purchasable),
    CONSTRAINT ck_product_presentations__sellable_requires_price CHECK (NOT is_sellable OR price_cents IS NOT NULL),
    CONSTRAINT ck_product_presentations__default_sale_sellable CHECK (NOT is_default_sale OR is_sellable),
    CONSTRAINT ck_product_presentations__default_purchase_purchasable CHECK (NOT is_default_purchase OR is_purchasable)
);

COMMENT ON TABLE catalog.product_presentations IS
    'Presentaciones de un producto: cada forma en la que se vende o se compra, con su factor de conversión a unidad base. Ejemplos — gaseosa (base UNIDAD): "Unidad" factor 1 vendible, "Six-pack" factor 6 vendible con su propio precio, "Caja x24" factor 24 solo comprable; huevos (base UNIDAD): "Unidad" factor 1 y "Docena" factor 12; arroz (base KG): "Kilo" factor 1 vendible, "Saco 50 kg" factor 50 comprable. Vender/comprar una presentación mueve stock por cantidad × factor en unidad base. El precio vigente vive aquí; el histórico queda congelado en sale_items.';
COMMENT ON COLUMN catalog.product_presentations.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN catalog.product_presentations.product_id IS 'Producto al que pertenece la presentación.';
COMMENT ON COLUMN catalog.product_presentations.name IS 'Nombre de la presentación como aparece en ticket y compras (p. ej. "Unidad", "Six-pack", "Caja x 24", "Kilo"); único por producto sin distinción de mayúsculas.';
COMMENT ON COLUMN catalog.product_presentations.factor IS 'Unidades base contenidas en esta presentación (six-pack de gaseosas = 6.000; saco de arroz = 50.000). Fraccionable para casos como "medio kilo" preempacado (0.500).';
COMMENT ON COLUMN catalog.product_presentations.price_cents IS 'Precio de venta vigente de la presentación en céntimos de sol, IGV contenido; obligatorio si es vendible (CHECK). NULL para presentaciones solo de compra. Para is_open_price es apenas la sugerencia.';
COMMENT ON COLUMN catalog.product_presentations.is_sellable IS 'true = aparece en el POS y puede venderse. Escanear el código de una presentación no vendible (p. ej. la caja del proveedor) muestra aviso en vez de vender.';
COMMENT ON COLUMN catalog.product_presentations.is_purchasable IS 'true = seleccionable al registrar compras (cajas, sacos, planchas). Default false: la presentación típica nace solo vendible.';
COMMENT ON COLUMN catalog.product_presentations.is_default_sale IS 'true = presentación que el POS usa al buscar el producto por nombre o botonera (sin escanear código). A lo sumo una por producto (índice parcial); exige is_sellable (CHECK).';
COMMENT ON COLUMN catalog.product_presentations.is_default_purchase IS 'true = presentación preseleccionada al registrar compras del producto. A lo sumo una por producto (índice parcial); exige is_purchasable (CHECK).';
COMMENT ON COLUMN catalog.product_presentations.is_active IS 'false = presentación retirada; se conserva porque ventas y compras históricas la referencian.';
COMMENT ON COLUMN catalog.product_presentations.updated_seq IS 'Posición en el reloj lógico de sync; los cambios de precio llegan al POS por pull.';
COMMENT ON COLUMN catalog.product_presentations.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN catalog.product_presentations.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE catalog.product_barcodes (
    id                      uuid        NOT NULL DEFAULT uuidv7(),
    product_presentation_id uuid        NOT NULL,
    barcode                 text        NOT NULL,
    is_active               boolean     NOT NULL DEFAULT true,
    updated_seq             bigint      NOT NULL DEFAULT nextval('sync.sync_seq'),
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_product_barcodes PRIMARY KEY (id),
    CONSTRAINT ck_product_barcodes__format CHECK (barcode ~ '^[0-9A-Za-z-]{3,64}$')
);

COMMENT ON TABLE catalog.product_barcodes IS
    'Códigos escaneables, N por presentación: el mismo producto puede traer EAN distintos por lote/país, y la unidad, el six-pack y la caja traen códigos diferentes. Escanear resuelve código → presentación → producto (precio y factor incluidos). También admite códigos internos cortos (PLU) para granel sin empaque. Único global: un código no puede apuntar a dos presentaciones.';
COMMENT ON COLUMN catalog.product_barcodes.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN catalog.product_barcodes.product_presentation_id IS 'Presentación a la que resuelve este código al escanear.';
COMMENT ON COLUMN catalog.product_barcodes.barcode IS 'Código EAN-8/EAN-13/UPC o código interno corto; alfanumérico con guiones, 3-64 caracteres (CHECK). Único global (índice ux_product_barcodes__barcode).';
COMMENT ON COLUMN catalog.product_barcodes.is_active IS 'false = código retirado (soft delete: el POS necesita enterarse por pull; un DELETE físico jamás le llegaría).';
COMMENT ON COLUMN catalog.product_barcodes.updated_seq IS 'Posición en el reloj lógico de sync para el pull incremental del POS.';
COMMENT ON COLUMN catalog.product_barcodes.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN catalog.product_barcodes.updated_at IS 'Fecha de última modificación (mantenida por trigger).';
