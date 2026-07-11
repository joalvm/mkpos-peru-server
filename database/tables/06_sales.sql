-- =============================================================================
-- tables/06_sales.sql — Ventas (append-only; nacen en el POS, llegan por sync).
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE sales.sales (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    branch_id       uuid        NOT NULL,
    terminal_id     uuid        NOT NULL,
    cash_session_id uuid        NOT NULL,
    user_id         uuid        NOT NULL,
    customer_id     uuid        NULL,
    status          sales.sale_status NOT NULL DEFAULT 'COMPLETADA',
    local_number    bigint      NOT NULL,
    sold_at         timestamptz NOT NULL,
    sold_on_local   date        NOT NULL,
    subtotal_cents  bigint      NOT NULL,
    discount_cents  bigint      NOT NULL DEFAULT 0,
    icbper_cents    bigint      NOT NULL DEFAULT 0,
    total_cents     bigint      NOT NULL,
    tax_cents       bigint      NOT NULL DEFAULT 0,
    voided_at       timestamptz NULL,
    voided_by       uuid        NULL,
    void_reason     text        NULL,
    received_at     timestamptz NOT NULL DEFAULT now(),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_sales PRIMARY KEY (id),
    CONSTRAINT ck_sales__amounts_non_negative CHECK (
        subtotal_cents >= 0 AND discount_cents >= 0 AND icbper_cents >= 0 AND total_cents >= 0
    ),
    CONSTRAINT ck_sales__total_consistent CHECK (
        total_cents = subtotal_cents - discount_cents + icbper_cents
    ),
    CONSTRAINT ck_sales__tax_within_total CHECK (tax_cents >= 0 AND tax_cents <= total_cents),
    CONSTRAINT ck_sales__local_number_positive CHECK (local_number > 0),
    CONSTRAINT ck_sales__void_coherence CHECK (
        (status = 'COMPLETADA' AND voided_at IS NULL AND voided_by IS NULL AND void_reason IS NULL)
        OR (status = 'ANULADA' AND voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL)
    )
);

COMMENT ON TABLE sales.sales IS
    'Ventas registradas en las terminales POS. El id lo genera la terminal (UUIDv7 local, la venta nace offline) y llega al servidor por sync push idempotente. Nunca se edita ni borra: anular marca ANULADA y revierte stock con movimientos ANULACION_VENTA.';
COMMENT ON COLUMN sales.sales.id IS 'Identificador único (UUIDv7) generado por la terminal al momento de vender, sin depender de la red.';
COMMENT ON COLUMN sales.sales.branch_id IS 'Sucursal donde ocurrió la venta.';
COMMENT ON COLUMN sales.sales.terminal_id IS 'Terminal que registró la venta.';
COMMENT ON COLUMN sales.sales.cash_session_id IS 'Sesión de caja abierta bajo la cual se cobró; toda venta exige caja abierta.';
COMMENT ON COLUMN sales.sales.user_id IS 'Cajero que realizó la venta (login por PIN en el POS).';
COMMENT ON COLUMN sales.sales.customer_id IS 'Cliente identificado; NULL = venta anónima (el caso normal).';
COMMENT ON COLUMN sales.sales.status IS 'COMPLETADA o ANULADA; la anulación conserva todo el registro.';
COMMENT ON COLUMN sales.sales.local_number IS 'Correlativo local de la terminal (1, 2, 3…); único por terminal. Es el número que ve el cliente en su ticket.';
COMMENT ON COLUMN sales.sales.sold_at IS 'Momento exacto de la venta según el reloj de la terminal (timestamptz).';
COMMENT ON COLUMN sales.sales.sold_on_local IS 'Fecha de negocio local (día de la tienda) calculada en la terminal; base de cierres y reportes diarios sin corrimientos de zona horaria.';
COMMENT ON COLUMN sales.sales.subtotal_cents IS 'Suma de los totales de los ítems (mercadería, IGV contenido), en céntimos de sol. NO incluye ICBPER.';
COMMENT ON COLUMN sales.sales.discount_cents IS 'Descuento global aplicado a la venta, en céntimos; 0 si no hubo. También absorbe el redondeo a favor del cliente al cobrar efectivo (céntimos sin moneda física).';
COMMENT ON COLUMN sales.sales.icbper_cents IS 'ICBPER total de la venta (Σ sale_items.icbper_cents): impuesto a las bolsas plásticas, único tributo que se SUMA encima del precio y no integra la base del IGV. 0 mientras el negocio sea informal.';
COMMENT ON COLUMN sales.sales.total_cents IS 'Total cobrado = subtotal − descuento + ICBPER (garantizado por CHECK). La suma de payments debe igualarlo (regla de aplicación: no expresable como CHECK entre tablas).';
COMMENT ON COLUMN sales.sales.tax_cents IS 'IGV contenido en la porción de mercadería del total (Σ sale_items.tax_cents; los precios son finales, el impuesto nunca se suma encima). 0 mientras el negocio sea informal (business_settings.is_formalized = false).';
COMMENT ON COLUMN sales.sales.voided_at IS 'Momento de la anulación; NULL si la venta sigue completada.';
COMMENT ON COLUMN sales.sales.voided_by IS 'Usuario que autorizó la anulación (exige permiso sales.void).';
COMMENT ON COLUMN sales.sales.void_reason IS 'Motivo obligatorio de la anulación (error de cobro, cliente se retractó…).';
COMMENT ON COLUMN sales.sales.received_at IS 'Momento en que el servidor recibió la venta vía sync; comparado con sold_at mide el atraso de sincronización.';
COMMENT ON COLUMN sales.sales.created_at IS 'Fecha de inserción del registro en el servidor.';
COMMENT ON COLUMN sales.sales.updated_at IS 'Fecha de última modificación (solo cambia al anular; mantenida por trigger).';


CREATE TABLE sales.sale_items (
    id                      uuid            NOT NULL DEFAULT uuidv7(),
    sale_id                 uuid            NOT NULL,
    product_id              uuid            NOT NULL,
    product_presentation_id uuid            NOT NULL,
    product_name            text            NOT NULL,
    presentation_name       text            NOT NULL,
    base_unit               catalog.unit_type       NOT NULL,
    factor                  numeric(10,3)   NOT NULL,
    quantity                numeric(10,3)   NOT NULL,
    unit_price_cents        bigint          NOT NULL,
    total_cents             bigint          NOT NULL,
    icbper_cents            bigint          NOT NULL DEFAULT 0,
    tax_affectation         catalog.tax_affectation NOT NULL,
    tax_rate_pct            numeric(5,2)    NOT NULL DEFAULT 0,
    tax_cents               bigint          NOT NULL DEFAULT 0,
    created_at              timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT pk_sale_items PRIMARY KEY (id),
    CONSTRAINT ck_sale_items__quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_sale_items__factor_positive CHECK (factor > 0),
    CONSTRAINT ck_sale_items__prices_non_negative CHECK (unit_price_cents >= 0 AND total_cents >= 0),
    CONSTRAINT ck_sale_items__icbper_non_negative CHECK (icbper_cents >= 0),
    CONSTRAINT ck_sale_items__tax_rate_range CHECK (tax_rate_pct >= 0 AND tax_rate_pct <= 100),
    CONSTRAINT ck_sale_items__tax_within_total CHECK (tax_cents >= 0 AND tax_cents <= total_cents)
);

COMMENT ON TABLE sales.sale_items IS
    'Líneas de una venta. Cada línea vende una PRESENTACIÓN (unidad, six-pack, kilo) y congela nombre, presentación, factor, unidad base, precio y snapshot fiscal al momento de vender: la venta es un hecho histórico que no cambia aunque el catálogo cambie. El movimiento de stock asociado descarga cantidad × factor en unidad base. Inmutable.';
COMMENT ON COLUMN sales.sale_items.id IS 'Identificador único (UUIDv7) generado por la terminal.';
COMMENT ON COLUMN sales.sale_items.sale_id IS 'Venta a la que pertenece la línea.';
COMMENT ON COLUMN sales.sale_items.product_id IS 'Producto vendido (referencia al catálogo vigente).';
COMMENT ON COLUMN sales.sale_items.product_presentation_id IS 'Presentación vendida (referencia al catálogo vigente); factor y nombre quedan además congelados en esta fila.';
COMMENT ON COLUMN sales.sale_items.product_name IS 'Nombre del producto al momento de la venta (snapshot para tickets y reportes históricos).';
COMMENT ON COLUMN sales.sale_items.presentation_name IS 'Nombre de la presentación al momento de la venta (snapshot: "Six-pack", "Kilo").';
COMMENT ON COLUMN sales.sale_items.base_unit IS 'Unidad base del producto al momento de la venta (snapshot); en ella se expresa el movimiento de stock.';
COMMENT ON COLUMN sales.sale_items.factor IS 'Unidades base por presentación al momento de la venta (snapshot): el stock descargado fue cantidad × factor, y esa aritmética histórica no cambia si la presentación se redefine.';
COMMENT ON COLUMN sales.sale_items.quantity IS 'Cantidad de presentaciones vendidas; admite fracciones para granel (0.250 de la presentación "Kilo").';
COMMENT ON COLUMN sales.sale_items.unit_price_cents IS 'Precio cobrado por presentación, en céntimos (snapshot del precio vigente al vender).';
COMMENT ON COLUMN sales.sale_items.total_cents IS 'Total de la línea en céntimos: cantidad × precio unitario, redondeado por la regla canónica única (docs/plans/INDEX.md). NO incluye ICBPER.';
COMMENT ON COLUMN sales.sale_items.icbper_cents IS 'ICBPER de la línea: cantidad × business_settings.icbper_cents si el producto es bolsa plástica (snapshot); se suma encima del precio y no integra la base del IGV. 0 mientras el negocio sea informal.';
COMMENT ON COLUMN sales.sale_items.tax_affectation IS 'Afectación IGV del producto al momento de la venta (snapshot de products.tax_affectation): la clasificación fiscal histórica no cambia si se reclasifica el producto.';
COMMENT ON COLUMN sales.sale_items.tax_rate_pct IS 'Tasa de IGV aplicada a la línea al vender (snapshot): 0 si el negocio era informal o la línea es EXONERADO/INAFECTO; 18.00 típico para GRAVADO ya formalizado.';
COMMENT ON COLUMN sales.sale_items.tax_cents IS 'IGV contenido en total_cents de la línea: total − round(total / (1 + tasa/100)), redondeo definido en un solo lugar por la aplicación. 0 mientras el negocio sea informal.';
COMMENT ON COLUMN sales.sale_items.created_at IS 'Fecha de inserción del registro en el servidor.';


CREATE TABLE sales.payments (
    id           uuid           NOT NULL DEFAULT uuidv7(),
    sale_id      uuid           NOT NULL,
    method       sales.payment_method NOT NULL,
    amount_cents bigint         NOT NULL,
    reference    text           NULL,
    created_at   timestamptz    NOT NULL DEFAULT now(),

    CONSTRAINT pk_payments PRIMARY KEY (id),
    CONSTRAINT ck_payments__amount_positive CHECK (amount_cents > 0)
);

COMMENT ON TABLE sales.payments IS
    'Pagos de una venta. Admite pago dividido (parte efectivo, parte Yape). La suma de pagos debe igualar el total de la venta (regla de aplicación). Solo los pagos EFECTIVO cuentan para el arqueo de caja. Inmutable.';
COMMENT ON COLUMN sales.payments.id IS 'Identificador único (UUIDv7) generado por la terminal.';
COMMENT ON COLUMN sales.payments.sale_id IS 'Venta que se está pagando.';
COMMENT ON COLUMN sales.payments.method IS 'Método de pago: EFECTIVO, YAPE o PLIN.';
COMMENT ON COLUMN sales.payments.amount_cents IS 'Monto pagado con este método, en céntimos de sol; siempre positivo.';
COMMENT ON COLUMN sales.payments.reference IS 'Número de operación de Yape/Plin digitado por el cajero; NULL para efectivo.';
COMMENT ON COLUMN sales.payments.created_at IS 'Fecha de inserción del registro en el servidor.';


CREATE TABLE sales.sale_documents (
    id            uuid          NOT NULL DEFAULT uuidv7(),
    sale_id       uuid          NOT NULL,
    doc_type      sales.document_type NOT NULL,
    series        text          NOT NULL,
    number        bigint        NOT NULL,
    customer_name text          NULL,
    issued_at     timestamptz   NOT NULL,
    created_at    timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_sale_documents PRIMARY KEY (id),
    CONSTRAINT ck_sale_documents__number_positive CHECK (number > 0)
);

COMMENT ON TABLE sales.sale_documents IS
    'Comprobantes emitidos por venta. Hoy solo NOTA_VENTA; la estructura ya soporta BOLETA/FACTURA para la formalización (los campos SUNAT/PSE se agregarán de forma aditiva; anular una venta con boleta emitida exigirá NOTA_CREDITO — futuro ADD VALUE en F3). Una venta tiene exactamente un comprobante.';
COMMENT ON COLUMN sales.sale_documents.id IS 'Identificador único (UUIDv7) generado por la terminal.';
COMMENT ON COLUMN sales.sale_documents.sale_id IS 'Venta que respalda este comprobante.';
COMMENT ON COLUMN sales.sale_documents.doc_type IS 'Tipo de comprobante emitido.';
COMMENT ON COLUMN sales.sale_documents.series IS 'Serie del comprobante. Para NOTA_VENTA es el código de la terminal (T01): cada terminal numera su propia serie offline sin chocar con otras.';
COMMENT ON COLUMN sales.sale_documents.number IS 'Número correlativo dentro de la serie; único junto con doc_type y series.';
COMMENT ON COLUMN sales.sale_documents.customer_name IS 'Nombre digitado para una nota de venta nominada ("a nombre de…") cuando el cliente no está registrado en customers; snapshot impreso en el ticket. NULL en la venta anónima normal.';
COMMENT ON COLUMN sales.sale_documents.issued_at IS 'Momento de emisión del comprobante (normalmente el de la venta).';
COMMENT ON COLUMN sales.sale_documents.created_at IS 'Fecha de inserción del registro en el servidor.';
