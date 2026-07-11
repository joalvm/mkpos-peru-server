-- =============================================================================
-- tables/99_relations.sql — TODAS las claves foráneas del esquema.
-- Separadas de los CREATE TABLE (convención del proyecto): el panorama de cada
-- dominio se lee de corrido y el orden de creación de tablas entre archivos
-- deja de importar. ON DELETE RESTRICT por regla: nada operativo se borra en
-- cascada; la única excepción documentada es la cadena de rotación de
-- refresh_tokens (SET NULL). Toda FK tiene su índice en indexes/.
-- =============================================================================

-- --- 01. Organización ---------------------------------------------------------

ALTER TABLE org.branches
    ADD CONSTRAINT fk_branches__warehouse_id
        FOREIGN KEY (warehouse_id) REFERENCES org.warehouses (id) ON DELETE RESTRICT;

-- --- 02. Identidad y acceso ---------------------------------------------------

ALTER TABLE access.user_roles
    ADD CONSTRAINT fk_user_roles__user_id
        FOREIGN KEY (user_id) REFERENCES access.users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_user_roles__role_id
        FOREIGN KEY (role_id) REFERENCES access.roles (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_user_roles__branch_id
        FOREIGN KEY (branch_id) REFERENCES org.branches (id) ON DELETE RESTRICT;

ALTER TABLE access.role_permissions
    ADD CONSTRAINT fk_role_permissions__role_id
        FOREIGN KEY (role_id) REFERENCES access.roles (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_role_permissions__permission_id
        FOREIGN KEY (permission_id) REFERENCES access.permissions (id) ON DELETE RESTRICT;

ALTER TABLE access.refresh_tokens
    ADD CONSTRAINT fk_refresh_tokens__user_id
        FOREIGN KEY (user_id) REFERENCES access.users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_refresh_tokens__replaced_by_id
        FOREIGN KEY (replaced_by_id) REFERENCES access.refresh_tokens (id) ON DELETE SET NULL;

-- --- 03. Terminales -----------------------------------------------------------

ALTER TABLE terminals.terminals
    ADD CONSTRAINT fk_terminals__branch_id
        FOREIGN KEY (branch_id) REFERENCES org.branches (id) ON DELETE RESTRICT;

ALTER TABLE terminals.terminal_enrollment_codes
    ADD CONSTRAINT fk_terminal_enrollment_codes__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals.terminals (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_terminal_enrollment_codes__created_by
        FOREIGN KEY (created_by) REFERENCES access.users (id) ON DELETE RESTRICT;

ALTER TABLE terminals.terminal_credentials
    ADD CONSTRAINT fk_terminal_credentials__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals.terminals (id) ON DELETE RESTRICT;

-- --- 04. Catálogo -------------------------------------------------------------

ALTER TABLE catalog.products
    ADD CONSTRAINT fk_products__category_id
        FOREIGN KEY (category_id) REFERENCES catalog.product_categories (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_products__brand_id
        FOREIGN KEY (brand_id) REFERENCES catalog.brands (id) ON DELETE RESTRICT;

ALTER TABLE catalog.product_presentations
    ADD CONSTRAINT fk_product_presentations__product_id
        FOREIGN KEY (product_id) REFERENCES catalog.products (id) ON DELETE RESTRICT;

ALTER TABLE catalog.product_barcodes
    ADD CONSTRAINT fk_product_barcodes__product_presentation_id
        FOREIGN KEY (product_presentation_id) REFERENCES catalog.product_presentations (id) ON DELETE RESTRICT;

-- --- 06. Ventas ---------------------------------------------------------------

ALTER TABLE sales.sales
    ADD CONSTRAINT fk_sales__branch_id
        FOREIGN KEY (branch_id) REFERENCES org.branches (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals.terminals (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__cash_session_id
        FOREIGN KEY (cash_session_id) REFERENCES cash.cash_sessions (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__user_id
        FOREIGN KEY (user_id) REFERENCES access.users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__customer_id
        FOREIGN KEY (customer_id) REFERENCES customers.customers (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales__voided_by
        FOREIGN KEY (voided_by) REFERENCES access.users (id) ON DELETE RESTRICT;

ALTER TABLE sales.sale_items
    ADD CONSTRAINT fk_sale_items__sale_id
        FOREIGN KEY (sale_id) REFERENCES sales.sales (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sale_items__product_id
        FOREIGN KEY (product_id) REFERENCES catalog.products (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sale_items__product_presentation_id
        FOREIGN KEY (product_presentation_id) REFERENCES catalog.product_presentations (id) ON DELETE RESTRICT;

ALTER TABLE sales.payments
    ADD CONSTRAINT fk_payments__sale_id
        FOREIGN KEY (sale_id) REFERENCES sales.sales (id) ON DELETE RESTRICT;

ALTER TABLE sales.sale_documents
    ADD CONSTRAINT fk_sale_documents__sale_id
        FOREIGN KEY (sale_id) REFERENCES sales.sales (id) ON DELETE RESTRICT;

-- --- 07. Inventario -----------------------------------------------------------

ALTER TABLE inventory.stock_movements
    ADD CONSTRAINT fk_stock_movements__warehouse_id
        FOREIGN KEY (warehouse_id) REFERENCES org.warehouses (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__product_id
        FOREIGN KEY (product_id) REFERENCES catalog.products (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__sale_item_id
        FOREIGN KEY (sale_item_id) REFERENCES sales.sale_items (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__purchase_item_id
        FOREIGN KEY (purchase_item_id) REFERENCES purchases.purchase_items (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__inventory_count_item_id
        FOREIGN KEY (inventory_count_item_id) REFERENCES inventory.inventory_count_items (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_stock_movements__user_id
        FOREIGN KEY (user_id) REFERENCES access.users (id) ON DELETE RESTRICT;

ALTER TABLE inventory.inventory_counts
    ADD CONSTRAINT fk_inventory_counts__warehouse_id
        FOREIGN KEY (warehouse_id) REFERENCES org.warehouses (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_inventory_counts__created_by
        FOREIGN KEY (created_by) REFERENCES access.users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_inventory_counts__applied_by
        FOREIGN KEY (applied_by) REFERENCES access.users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_inventory_counts__cancelled_by
        FOREIGN KEY (cancelled_by) REFERENCES access.users (id) ON DELETE RESTRICT;

ALTER TABLE inventory.inventory_count_items
    ADD CONSTRAINT fk_inventory_count_items__inventory_count_id
        FOREIGN KEY (inventory_count_id) REFERENCES inventory.inventory_counts (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_inventory_count_items__product_id
        FOREIGN KEY (product_id) REFERENCES catalog.products (id) ON DELETE RESTRICT;

-- --- 08. Caja -----------------------------------------------------------------

ALTER TABLE cash.cash_sessions
    ADD CONSTRAINT fk_cash_sessions__branch_id
        FOREIGN KEY (branch_id) REFERENCES org.branches (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cash_sessions__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals.terminals (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cash_sessions__opened_by
        FOREIGN KEY (opened_by) REFERENCES access.users (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cash_sessions__closed_by
        FOREIGN KEY (closed_by) REFERENCES access.users (id) ON DELETE RESTRICT;

ALTER TABLE cash.cash_movements
    ADD CONSTRAINT fk_cash_movements__cash_session_id
        FOREIGN KEY (cash_session_id) REFERENCES cash.cash_sessions (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_cash_movements__user_id
        FOREIGN KEY (user_id) REFERENCES access.users (id) ON DELETE RESTRICT;

-- --- 09. Compras --------------------------------------------------------------

ALTER TABLE purchases.purchases
    ADD CONSTRAINT fk_purchases__warehouse_id
        FOREIGN KEY (warehouse_id) REFERENCES org.warehouses (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_purchases__supplier_id
        FOREIGN KEY (supplier_id) REFERENCES purchases.suppliers (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_purchases__created_by
        FOREIGN KEY (created_by) REFERENCES access.users (id) ON DELETE RESTRICT;

ALTER TABLE purchases.purchase_items
    ADD CONSTRAINT fk_purchase_items__purchase_id
        FOREIGN KEY (purchase_id) REFERENCES purchases.purchases (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_purchase_items__product_id
        FOREIGN KEY (product_id) REFERENCES catalog.products (id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_purchase_items__product_presentation_id
        FOREIGN KEY (product_presentation_id) REFERENCES catalog.product_presentations (id) ON DELETE RESTRICT;

-- --- 10. Sincronización -------------------------------------------------------

ALTER TABLE sync.sync_ingest_log
    ADD CONSTRAINT fk_sync_ingest_log__terminal_id
        FOREIGN KEY (terminal_id) REFERENCES terminals.terminals (id) ON DELETE RESTRICT;

-- --- 11. Reportes ---------------------------------------------------------------

ALTER TABLE reports.reports
    ADD CONSTRAINT fk_reports__requested_by
        FOREIGN KEY (requested_by) REFERENCES access.users (id) ON DELETE RESTRICT;

-- --- 12. Notificaciones ---------------------------------------------------------

ALTER TABLE notifications.notifications
    ADD CONSTRAINT fk_notifications__user_id
        FOREIGN KEY (user_id) REFERENCES access.users (id) ON DELETE RESTRICT;

-- --- 13. Logs -------------------------------------------------------------------
-- A propósito SIN claves foráneas (única excepción del esquema): son tablas
-- particionadas de telemetría de alta escritura y retención corta; la
-- correlación core ↔ satélites es por request_id (mismo UUID) y la garantiza
-- el writer del server, no una constraint. Ver tables/13_logs.sql.
