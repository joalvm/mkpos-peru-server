-- =============================================================================
-- indexes.sql — Índices únicos, de FK y de consulta.
-- Reglas:
--   · Toda FK lleva índice (ON DELETE RESTRICT los usa, y los joins también);
--     se omite solo cuando otro índice ya empieza por esa columna (se indica).
--   · ux_ = único · ix_ = no único. Todos con COMMENT.
--   · Los índices implícitos de las PK no se comentan: su propósito es evidente.
-- =============================================================================

-- --- 1. Organización e identidad --------------------------------------------

CREATE UNIQUE INDEX ux_branches__code ON branches (code);
COMMENT ON INDEX ux_branches__code IS 'Un código de sucursal no se repite.';

CREATE INDEX ix_branches__updated_seq ON branches (updated_seq);
COMMENT ON INDEX ix_branches__updated_seq IS 'Escaneo por cursor del pull de sync.';

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

-- --- 2. Terminales -----------------------------------------------------------

CREATE UNIQUE INDEX ux_terminals__branch_code ON terminals (branch_id, code);
COMMENT ON INDEX ux_terminals__branch_code IS 'Código de terminal único por sucursal (T01 puede existir en dos tiendas); cubre además la FK branch_id.';

CREATE UNIQUE INDEX ux_terminal_enrollment_codes__code_hash
    ON terminal_enrollment_codes (code_hash);
COMMENT ON INDEX ux_terminal_enrollment_codes__code_hash IS 'Búsqueda del código presentado al enrolar; único.';

CREATE INDEX ix_terminal_enrollment_codes__terminal_id
    ON terminal_enrollment_codes (terminal_id);
COMMENT ON INDEX ix_terminal_enrollment_codes__terminal_id IS 'Índice de FK terminal_id.';

CREATE INDEX ix_terminal_enrollment_codes__created_by
    ON terminal_enrollment_codes (created_by);
COMMENT ON INDEX ix_terminal_enrollment_codes__created_by IS 'Índice de FK created_by.';

CREATE UNIQUE INDEX ux_terminal_credentials__client_id ON terminal_credentials (client_id);
COMMENT ON INDEX ux_terminal_credentials__client_id IS 'Búsqueda por client_id en cada petición de token M2M; único.';

CREATE UNIQUE INDEX ux_terminal_credentials__active_per_terminal
    ON terminal_credentials (terminal_id) WHERE revoked_at IS NULL;
COMMENT ON INDEX ux_terminal_credentials__active_per_terminal IS 'Garantiza a lo sumo una credencial vigente por terminal.';

CREATE INDEX ix_terminal_credentials__terminal_id ON terminal_credentials (terminal_id);
COMMENT ON INDEX ix_terminal_credentials__terminal_id IS 'Índice de FK completo (el único parcial no cubre credenciales revocadas).';

-- --- 3. Catálogo -------------------------------------------------------------

CREATE UNIQUE INDEX ux_categories__name ON categories (lower(name));
COMMENT ON INDEX ux_categories__name IS 'Nombre de categoría único sin distinción de mayúsculas.';

CREATE INDEX ix_categories__updated_seq ON categories (updated_seq);
COMMENT ON INDEX ix_categories__updated_seq IS 'Escaneo por cursor del pull de sync.';

CREATE UNIQUE INDEX ux_products__barcode ON products (barcode) WHERE barcode IS NOT NULL;
COMMENT ON INDEX ux_products__barcode IS 'Código de barras único cuando existe; parcial porque los productos a granel no tienen.';

CREATE INDEX ix_products__category_id ON products (category_id);
COMMENT ON INDEX ix_products__category_id IS 'Índice de FK: listado de productos por categoría.';

CREATE INDEX ix_products__name_trgm ON products USING gin (name gin_trgm_ops);
COMMENT ON INDEX ix_products__name_trgm IS 'Autocompletado por similitud de nombre (pg_trgm) para productos sin código de barras.';

CREATE INDEX ix_products__updated_seq ON products (updated_seq);
COMMENT ON INDEX ix_products__updated_seq IS 'Escaneo por cursor del pull de sync (catálogo y precios).';

-- --- 4. Clientes -------------------------------------------------------------

CREATE UNIQUE INDEX ux_customers__doc ON customers (doc_type, doc_number);
COMMENT ON INDEX ux_customers__doc IS 'Un documento identifica a un solo cliente.';

CREATE INDEX ix_customers__updated_seq ON customers (updated_seq);
COMMENT ON INDEX ix_customers__updated_seq IS 'Escaneo por cursor del pull de sync.';

-- --- 5. Ventas ---------------------------------------------------------------

CREATE UNIQUE INDEX ux_sales__terminal_local_number ON sales (terminal_id, local_number);
COMMENT ON INDEX ux_sales__terminal_local_number IS 'El correlativo local no se repite dentro de una terminal; cubre además la FK terminal_id.';

CREATE INDEX ix_sales__branch_sold_on ON sales (branch_id, sold_on_local);
COMMENT ON INDEX ix_sales__branch_sold_on IS 'Reportes y cierres diarios por sucursal y fecha de negocio; cubre además la FK branch_id.';

CREATE INDEX ix_sales__cash_session_id ON sales (cash_session_id);
COMMENT ON INDEX ix_sales__cash_session_id IS 'Índice de FK: ventas de una sesión de caja (cálculo del arqueo).';

CREATE INDEX ix_sales__user_id ON sales (user_id);
COMMENT ON INDEX ix_sales__user_id IS 'Índice de FK: ventas por cajero.';

CREATE INDEX ix_sales__customer_id ON sales (customer_id) WHERE customer_id IS NOT NULL;
COMMENT ON INDEX ix_sales__customer_id IS 'Índice de FK: historial de un cliente; parcial porque casi toda venta es anónima.';

CREATE INDEX ix_sales__voided_by ON sales (voided_by) WHERE voided_by IS NOT NULL;
COMMENT ON INDEX ix_sales__voided_by IS 'Índice de FK: auditoría de anulaciones por usuario; parcial.';

CREATE INDEX ix_sale_items__sale_id ON sale_items (sale_id);
COMMENT ON INDEX ix_sale_items__sale_id IS 'Índice de FK: líneas de una venta.';

CREATE INDEX ix_sale_items__product_id ON sale_items (product_id);
COMMENT ON INDEX ix_sale_items__product_id IS 'Índice de FK: historial de ventas de un producto (top productos).';

CREATE INDEX ix_payments__sale_id ON payments (sale_id);
COMMENT ON INDEX ix_payments__sale_id IS 'Índice de FK: pagos de una venta.';

CREATE UNIQUE INDEX ux_sale_documents__sale_id ON sale_documents (sale_id);
COMMENT ON INDEX ux_sale_documents__sale_id IS 'Una venta emite exactamente un comprobante; cubre además la FK sale_id.';

CREATE UNIQUE INDEX ux_sale_documents__doc ON sale_documents (doc_type, series, number);
COMMENT ON INDEX ux_sale_documents__doc IS 'No hay dos comprobantes con el mismo tipo, serie y número.';

-- --- 6. Inventario -----------------------------------------------------------

CREATE INDEX ix_stock_movements__branch_product
    ON stock_movements (branch_id, product_id, created_at);
COMMENT ON INDEX ix_stock_movements__branch_product IS 'Kardex de un producto en una sucursal y agregación de stock_levels; cubre además la FK branch_id.';

CREATE INDEX ix_stock_movements__product_id ON stock_movements (product_id);
COMMENT ON INDEX ix_stock_movements__product_id IS 'Índice de FK: movimientos de un producto en todas las sucursales.';

CREATE INDEX ix_stock_movements__sale_item_id ON stock_movements (sale_item_id)
    WHERE sale_item_id IS NOT NULL;
COMMENT ON INDEX ix_stock_movements__sale_item_id IS 'Índice de FK: trazabilidad venta → movimiento; parcial.';

CREATE INDEX ix_stock_movements__purchase_item_id ON stock_movements (purchase_item_id)
    WHERE purchase_item_id IS NOT NULL;
COMMENT ON INDEX ix_stock_movements__purchase_item_id IS 'Índice de FK: trazabilidad compra → movimiento; parcial.';

CREATE INDEX ix_stock_movements__user_id ON stock_movements (user_id);
COMMENT ON INDEX ix_stock_movements__user_id IS 'Índice de FK: auditoría de movimientos por usuario.';

-- --- 7. Caja -----------------------------------------------------------------

CREATE UNIQUE INDEX ux_cash_sessions__open_per_terminal
    ON cash_sessions (terminal_id) WHERE closed_at IS NULL;
COMMENT ON INDEX ux_cash_sessions__open_per_terminal IS 'Garantiza a lo sumo una sesión de caja abierta por terminal.';

CREATE INDEX ix_cash_sessions__terminal_id ON cash_sessions (terminal_id);
COMMENT ON INDEX ix_cash_sessions__terminal_id IS 'Índice de FK completo (el único parcial no cubre sesiones cerradas).';

CREATE INDEX ix_cash_sessions__branch_opened ON cash_sessions (branch_id, opened_at);
COMMENT ON INDEX ix_cash_sessions__branch_opened IS 'Historial de arqueos por sucursal y fecha; cubre además la FK branch_id.';

CREATE INDEX ix_cash_sessions__opened_by ON cash_sessions (opened_by);
COMMENT ON INDEX ix_cash_sessions__opened_by IS 'Índice de FK opened_by.';

CREATE INDEX ix_cash_sessions__closed_by ON cash_sessions (closed_by) WHERE closed_by IS NOT NULL;
COMMENT ON INDEX ix_cash_sessions__closed_by IS 'Índice de FK closed_by; parcial (NULL mientras la sesión está abierta).';

CREATE INDEX ix_cash_movements__cash_session_id ON cash_movements (cash_session_id);
COMMENT ON INDEX ix_cash_movements__cash_session_id IS 'Índice de FK: movimientos de una sesión (cálculo del arqueo).';

CREATE INDEX ix_cash_movements__user_id ON cash_movements (user_id);
COMMENT ON INDEX ix_cash_movements__user_id IS 'Índice de FK: auditoría de ingresos/retiros por usuario.';

-- --- 8. Compras --------------------------------------------------------------

CREATE UNIQUE INDEX ux_suppliers__ruc ON suppliers (ruc) WHERE ruc IS NOT NULL;
COMMENT ON INDEX ux_suppliers__ruc IS 'RUC único cuando existe; parcial porque los puestos del mayorista pueden no tener.';

CREATE INDEX ix_purchases__branch_id ON purchases (branch_id);
COMMENT ON INDEX ix_purchases__branch_id IS 'Índice de FK: compras por sucursal.';

CREATE INDEX ix_purchases__supplier_id ON purchases (supplier_id) WHERE supplier_id IS NOT NULL;
COMMENT ON INDEX ix_purchases__supplier_id IS 'Índice de FK: historial por proveedor; parcial.';

CREATE INDEX ix_purchases__created_by ON purchases (created_by);
COMMENT ON INDEX ix_purchases__created_by IS 'Índice de FK created_by.';

CREATE INDEX ix_purchase_items__purchase_id ON purchase_items (purchase_id);
COMMENT ON INDEX ix_purchase_items__purchase_id IS 'Índice de FK: líneas de una compra.';

CREATE INDEX ix_purchase_items__product_id ON purchase_items (product_id);
COMMENT ON INDEX ix_purchase_items__product_id IS 'Índice de FK: historial de costos de un producto.';

-- --- 9. Sincronización -------------------------------------------------------

CREATE UNIQUE INDEX ux_sync_ingest_log__event_id ON sync_ingest_log (event_id);
COMMENT ON INDEX ux_sync_ingest_log__event_id IS 'Clave de deduplicación del push idempotente: un evento se aplica una sola vez.';

CREATE INDEX ix_sync_ingest_log__terminal_received
    ON sync_ingest_log (terminal_id, received_at);
COMMENT ON INDEX ix_sync_ingest_log__terminal_received IS 'Auditoría de ingesta por terminal y fecha; cubre además la FK terminal_id.';
