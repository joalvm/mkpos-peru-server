-- =============================================================================
-- tables/09_purchases.sql — Proveedores y compras de mercadería.
-- Las compras entran por PRESENTACIONES (caja x24, saco 50 kg) y el stock
-- ingresa convertido a unidad base (cantidad × factor).
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE suppliers (
    id           uuid        NOT NULL DEFAULT uuidv7(),
    name         text        NOT NULL,
    ruc          text        NULL,
    contact_name text        NULL,
    phone        text        NULL,
    address      text        NULL,
    is_active    boolean     NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_suppliers PRIMARY KEY (id),
    CONSTRAINT ck_suppliers__ruc_format CHECK (ruc IS NULL OR ruc ~ '^[0-9]{11}$')
);

COMMENT ON TABLE suppliers IS
    'Proveedores: distribuidoras de Piura (Alvarez Bohl, Kompass…) y, opcionalmente, puestos frecuentes del mercado mayorista. A quién se le compra cada producto y a qué costo se deriva del historial de purchase_items (no hay catálogo producto-proveedor a propósito).';
COMMENT ON COLUMN suppliers.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN suppliers.name IS 'Nombre comercial del proveedor.';
COMMENT ON COLUMN suppliers.ruc IS 'RUC del proveedor (11 dígitos); único cuando existe. NULL para puestos informales del mayorista.';
COMMENT ON COLUMN suppliers.contact_name IS 'Nombre del vendedor o contacto que toma los pedidos; opcional.';
COMMENT ON COLUMN suppliers.phone IS 'Teléfono para hacer pedidos; opcional.';
COMMENT ON COLUMN suppliers.address IS 'Dirección del proveedor; opcional.';
COMMENT ON COLUMN suppliers.is_active IS 'false = ya no se le compra; se conserva por el historial de compras.';
COMMENT ON COLUMN suppliers.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN suppliers.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE purchases (
    id               uuid            NOT NULL DEFAULT uuidv7(),
    warehouse_id     uuid            NOT NULL,
    supplier_id      uuid            NULL,
    kind             purchase_kind   NOT NULL,
    status           purchase_status NOT NULL,
    doc_reference    text            NULL,
    ordered_at       timestamptz     NULL,
    received_at      timestamptz     NULL,
    total_cents      bigint          NOT NULL DEFAULT 0,
    perception_cents bigint          NOT NULL DEFAULT 0,
    note             text            NULL,
    created_by       uuid            NOT NULL,
    created_at       timestamptz     NOT NULL DEFAULT now(),
    updated_at       timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT pk_purchases PRIMARY KEY (id),
    CONSTRAINT ck_purchases__total_non_negative CHECK (total_cents >= 0),
    CONSTRAINT ck_purchases__perception_non_negative CHECK (perception_cents >= 0),
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
    'Compras de mercadería. MAYORISTA: se compra y recibe en el acto (nace RECIBIDA, proveedor opcional). DISTRIBUIDORA: pedido que llega días después (PEDIDA → RECIBIDA | CANCELADA, proveedor obligatorio). Pasar a RECIBIDA genera los movimientos de stock COMPRA (en unidad base: cantidad × factor de cada línea).';
COMMENT ON COLUMN purchases.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN purchases.warehouse_id IS 'Almacén donde entra la mercadería (por defecto el asignado a la sucursal que compra: branches.warehouse_id).';
COMMENT ON COLUMN purchases.supplier_id IS 'Proveedor; obligatorio para DISTRIBUIDORA (CHECK), opcional para MAYORISTA.';
COMMENT ON COLUMN purchases.kind IS 'Modalidad de compra: MAYORISTA o DISTRIBUIDORA; define el ciclo de estados permitido.';
COMMENT ON COLUMN purchases.status IS 'Estado del ciclo de vida; solo el paso a RECIBIDA ingresa stock.';
COMMENT ON COLUMN purchases.doc_reference IS 'Referencia del documento del proveedor (nro. de factura o guía) para conciliar; opcional.';
COMMENT ON COLUMN purchases.ordered_at IS 'Fecha del pedido; obligatoria para DISTRIBUIDORA, NULL para MAYORISTA (no hay pedido previo).';
COMMENT ON COLUMN purchases.received_at IS 'Fecha de recepción de la mercadería; NOT NULL exactamente cuando status = RECIBIDA (CHECK).';
COMMENT ON COLUMN purchases.total_cents IS 'Costo total de la mercadería en céntimos (Σ purchase_items.total_cents, mantenido por la aplicación). NO incluye la percepción.';
COMMENT ON COLUMN purchases.perception_cents IS 'Percepción de IGV cobrada por el proveedor en el comprobante (Régimen de Percepciones SUNAT: típico 2 % en gaseosas/agua/cerveza comprada a distribuidoras). Se registra aparte del costo: pagado = total + percepción; al formalizarse el negocio es crédito aplicable contra el IGV. 0 si el comprobante no trae percepción.';
COMMENT ON COLUMN purchases.note IS 'Observación libre (condiciones, faltantes, motivo de cancelación).';
COMMENT ON COLUMN purchases.created_by IS 'Usuario que registró la compra.';
COMMENT ON COLUMN purchases.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN purchases.updated_at IS 'Fecha de última modificación (mantenida por trigger).';


CREATE TABLE purchase_items (
    id                      uuid          NOT NULL DEFAULT uuidv7(),
    purchase_id             uuid          NOT NULL,
    product_id              uuid          NOT NULL,
    product_presentation_id uuid          NOT NULL,
    presentation_name       text          NOT NULL,
    factor                  numeric(10,3) NOT NULL,
    quantity                numeric(10,3) NOT NULL,
    unit_cost_cents         bigint        NOT NULL,
    total_cents             bigint        NOT NULL,
    created_at              timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_purchase_items PRIMARY KEY (id),
    CONSTRAINT ck_purchase_items__quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_purchase_items__factor_positive CHECK (factor > 0),
    CONSTRAINT ck_purchase_items__costs_non_negative CHECK (unit_cost_cents >= 0 AND total_cents >= 0)
);

COMMENT ON TABLE purchase_items IS
    'Líneas de una compra: qué presentaciones (caja x24, saco 50 kg), cuántas y a qué costo. Es la fuente del costo real histórico; el costo de referencia por unidad base (products.cost_cents = unit_cost ÷ factor) lo recalcula la aplicación al recibir. El stock ingresa en unidad base: cantidad × factor.';
COMMENT ON COLUMN purchase_items.id IS 'Identificador único (UUIDv7).';
COMMENT ON COLUMN purchase_items.purchase_id IS 'Compra a la que pertenece la línea.';
COMMENT ON COLUMN purchase_items.product_id IS 'Producto comprado.';
COMMENT ON COLUMN purchase_items.product_presentation_id IS 'Presentación comprada (caja, saco, plancha); su factor queda además congelado en esta fila.';
COMMENT ON COLUMN purchase_items.presentation_name IS 'Nombre de la presentación al momento de comprar (snapshot: "Caja x 24").';
COMMENT ON COLUMN purchase_items.factor IS 'Unidades base por presentación al momento de comprar (snapshot): el stock ingresado fue cantidad × factor y esa aritmética histórica no cambia si la presentación se redefine.';
COMMENT ON COLUMN purchase_items.quantity IS 'Cantidad de presentaciones compradas (2 cajas, 1.5 sacos); admite fracciones.';
COMMENT ON COLUMN purchase_items.unit_cost_cents IS 'Costo pagado por presentación, en céntimos.';
COMMENT ON COLUMN purchase_items.total_cents IS 'Costo total de la línea en céntimos: cantidad × costo unitario, redondeado por la regla canónica única.';
COMMENT ON COLUMN purchase_items.created_at IS 'Fecha de creación del registro.';
