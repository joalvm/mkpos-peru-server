-- =============================================================================
-- triggers.sql — Triggers de infraestructura.
--   · trg_*__set_updated_at : toda tabla mutable (con columna updated_at).
--   · trg_*__set_updated_seq: solo tablas que el POS descarga por pull
--     incremental (branches, users, categories, products, customers).
--     Las tablas RBAC (roles, permissions, role_permissions, user_roles) no lo
--     necesitan: viajan como snapshot completo en cada pull.
-- Las tablas-libro (stock_movements, payments, cash_movements, sale_items,
-- purchase_items, sync_ingest_log) son inmutables: sin triggers.
-- =============================================================================

-- --- updated_at --------------------------------------------------------------

CREATE TRIGGER trg_branches__set_updated_at
    BEFORE UPDATE ON branches
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_branches__set_updated_at ON branches IS
    'Mantiene branches.updated_at en cada modificación.';

CREATE TRIGGER trg_users__set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_users__set_updated_at ON users IS
    'Mantiene users.updated_at en cada modificación.';

CREATE TRIGGER trg_roles__set_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_roles__set_updated_at ON roles IS
    'Mantiene roles.updated_at en cada modificación.';

CREATE TRIGGER trg_terminals__set_updated_at
    BEFORE UPDATE ON terminals
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_terminals__set_updated_at ON terminals IS
    'Mantiene terminals.updated_at en cada modificación.';

CREATE TRIGGER trg_categories__set_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_categories__set_updated_at ON categories IS
    'Mantiene categories.updated_at en cada modificación.';

CREATE TRIGGER trg_products__set_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_products__set_updated_at ON products IS
    'Mantiene products.updated_at en cada modificación.';

CREATE TRIGGER trg_customers__set_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_customers__set_updated_at ON customers IS
    'Mantiene customers.updated_at en cada modificación.';

CREATE TRIGGER trg_sales__set_updated_at
    BEFORE UPDATE ON sales
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_sales__set_updated_at ON sales IS
    'Mantiene sales.updated_at (una venta solo se modifica al anularse).';

CREATE TRIGGER trg_cash_sessions__set_updated_at
    BEFORE UPDATE ON cash_sessions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_cash_sessions__set_updated_at ON cash_sessions IS
    'Mantiene cash_sessions.updated_at (cambia al cerrar la sesión).';

CREATE TRIGGER trg_suppliers__set_updated_at
    BEFORE UPDATE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_suppliers__set_updated_at ON suppliers IS
    'Mantiene suppliers.updated_at en cada modificación.';

CREATE TRIGGER trg_purchases__set_updated_at
    BEFORE UPDATE ON purchases
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_purchases__set_updated_at ON purchases IS
    'Mantiene purchases.updated_at (cambia al recibir o cancelar).';

-- --- updated_seq (pull incremental del POS) ----------------------------------

CREATE TRIGGER trg_branches__set_updated_seq
    BEFORE UPDATE ON branches
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_branches__set_updated_seq ON branches IS
    'Avanza branches.updated_seq para que el cambio entre en el próximo pull de las terminales.';

CREATE TRIGGER trg_users__set_updated_seq
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_users__set_updated_seq ON users IS
    'Avanza users.updated_seq; crítico para que cambios de PIN y bajas de personal lleguen al POS.';

CREATE TRIGGER trg_categories__set_updated_seq
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_categories__set_updated_seq ON categories IS
    'Avanza categories.updated_seq para el pull incremental del POS.';

CREATE TRIGGER trg_products__set_updated_seq
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_products__set_updated_seq ON products IS
    'Avanza products.updated_seq; así los cambios de precio llegan a las terminales en el siguiente pull.';

CREATE TRIGGER trg_customers__set_updated_seq
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_customers__set_updated_seq ON customers IS
    'Avanza customers.updated_seq para el pull incremental del POS.';
