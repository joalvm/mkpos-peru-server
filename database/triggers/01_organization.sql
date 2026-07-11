-- =============================================================================
-- triggers/01_organization.sql — Triggers de configuración y organización.
-- Reglas generales (aplican a toda la carpeta triggers/):
--   · trg_*__set_updated_at : toda tabla mutable (con columna updated_at).
--   · trg_*__set_updated_seq: solo tablas que el POS descarga por pull
--     incremental. Las tablas RBAC (roles, permissions, role_permissions,
--     user_roles) no lo necesitan: viajan como snapshot completo en cada pull.
--   · Las tablas-libro (stock_movements, payments, cash_movements, sale_items,
--     purchase_items, inventory_count_items, sync_ingest_log) son inmutables:
--     sin triggers.
--   · Solo infraestructura; la lógica de negocio vive en Go, jamás aquí.
-- =============================================================================

CREATE TRIGGER trg_business_settings__set_updated_at
    BEFORE UPDATE ON business_settings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_business_settings__set_updated_at ON business_settings IS
    'Mantiene business_settings.updated_at en cada modificación.';

CREATE TRIGGER trg_business_settings__set_updated_seq
    BEFORE UPDATE ON business_settings
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_business_settings__set_updated_seq ON business_settings IS
    'Avanza business_settings.updated_seq; los cambios de configuración (nombre, pie de ticket, formalización) llegan al POS en el siguiente pull.';

CREATE TRIGGER trg_warehouses__set_updated_at
    BEFORE UPDATE ON warehouses
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_warehouses__set_updated_at ON warehouses IS
    'Mantiene warehouses.updated_at en cada modificación.';

CREATE TRIGGER trg_warehouses__set_updated_seq
    BEFORE UPDATE ON warehouses
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_warehouses__set_updated_seq ON warehouses IS
    'Avanza warehouses.updated_seq; el POS conoce el almacén de su sucursal vía pull.';

CREATE TRIGGER trg_branches__set_updated_at
    BEFORE UPDATE ON branches
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
COMMENT ON TRIGGER trg_branches__set_updated_at ON branches IS
    'Mantiene branches.updated_at en cada modificación.';

CREATE TRIGGER trg_branches__set_updated_seq
    BEFORE UPDATE ON branches
    FOR EACH ROW EXECUTE FUNCTION set_updated_seq();
COMMENT ON TRIGGER trg_branches__set_updated_seq ON branches IS
    'Avanza branches.updated_seq para que el cambio (incluida la reasignación de almacén) entre en el próximo pull de las terminales.';
