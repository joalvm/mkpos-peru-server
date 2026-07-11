-- =============================================================================
-- seeds/system.sql — Datos que el sistema necesita SIEMPRE para funcionar:
-- roles base, catálogo de permisos y sus otorgamientos.
--
-- Idempotente: se puede re-ejecutar sin duplicar (ON CONFLICT). Se corre
-- después de init.sql en todo db:reset y también contra producción futura.
-- Los datos de prueba (sucursales, usuarios, productos demo) NO van aquí:
-- viven en seeds/dev.sql.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- --- Roles base (códigos en español, regla del proyecto) ---------------------

INSERT INTO roles (code, name, description, is_system) VALUES
    ('PROPIETARIO', 'Propietario',
     'Dueña del negocio: acceso total a todas las sucursales y configuración.', true),
    ('ENCARGADO', 'Encargado de tienda',
     'Administra la operación diaria de su sucursal: catálogo, stock, compras, caja y ventas. No gestiona usuarios ni sucursales.', true),
    ('CAJERO', 'Cajero',
     'Opera el POS: vende, abre y cierra su caja, registra clientes. Solo lectura del resto.', true)
ON CONFLICT (code) DO UPDATE
    SET name = EXCLUDED.name,
        description = EXCLUDED.description,
        is_system = EXCLUDED.is_system;

-- --- Catálogo de permisos ----------------------------------------------------
-- Códigos en inglés: son identificadores técnicos ligados a endpoints
-- (PROYECTO.md § 4), a diferencia de los enums de negocio.

INSERT INTO permissions (code, description) VALUES
    -- Sucursales y almacenes
    ('branches.read',    'Ver sucursales.'),
    ('branches.manage',  'Crear y editar sucursales (incluye asignarles almacén).'),
    ('warehouses.read',  'Ver almacenes.'),
    ('warehouses.manage','Crear y editar almacenes.'),
    -- Usuarios y RBAC
    ('users.read',       'Ver usuarios.'),
    ('users.manage',     'Crear y editar usuarios, asignar roles, resetear PIN/contraseña.'),
    ('roles.read',       'Ver roles y sus permisos.'),
    ('roles.manage',     'Crear y editar roles y sus permisos.'),
    -- Terminales
    ('terminals.read',   'Ver terminales y su estado.'),
    ('terminals.manage', 'Crear, editar y revocar terminales.'),
    ('terminals.enroll', 'Generar códigos de enrolamiento para terminales.'),
    -- Catálogo
    ('product_categories.read',   'Ver categorías de productos.'),
    ('product_categories.manage', 'Crear y editar categorías de productos.'),
    ('brands.read',      'Ver marcas.'),
    ('brands.manage',    'Crear y editar marcas.'),
    ('products.read',    'Ver productos, presentaciones, códigos de barras y precios.'),
    ('products.manage',  'Crear y editar productos, presentaciones y códigos de barras; cambiar precios.'),
    -- Clientes
    ('customers.read',   'Ver clientes.'),
    ('customers.manage', 'Crear y editar clientes.'),
    -- Proveedores y compras
    ('suppliers.read',   'Ver proveedores.'),
    ('suppliers.manage', 'Crear y editar proveedores.'),
    ('purchases.read',   'Ver compras.'),
    ('purchases.manage', 'Registrar compras, recibir pedidos, cancelar.'),
    -- Inventario
    ('stock.read',       'Ver stock, kardex y conteos físicos.'),
    ('stock.adjust',     'Registrar ajustes de inventario, mermas y conteos físicos (abrir, aplicar, cancelar).'),
    -- Ventas
    ('sales.read',       'Ver ventas.'),
    ('sales.create',     'Registrar ventas en el POS.'),
    ('sales.void',       'Anular ventas.'),
    -- Caja
    ('cash.read',        'Ver sesiones y movimientos de caja.'),
    ('cash.open',        'Abrir sesión de caja.'),
    ('cash.close',       'Cerrar sesión de caja (arqueo).'),
    ('cash.movement',    'Registrar ingresos y retiros de efectivo.'),
    -- Reportes
    ('reports.read',     'Ver reportes y dashboard.'),
    -- Configuración del negocio
    ('settings.read',    'Ver la configuración del negocio.'),
    ('settings.manage',  'Editar la configuración del negocio (nombre, ticket, formalización).')
ON CONFLICT (code) DO UPDATE
    SET description = EXCLUDED.description;

-- --- Otorgamientos -----------------------------------------------------------

-- PROPIETARIO: todos los permisos, siempre (a propósito un CROSS JOIN: cualquier
-- permiso nuevo que entre al catálogo le queda otorgado automáticamente).
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'PROPIETARIO'
ON CONFLICT DO NOTHING;

-- ENCARGADO: opera su tienda completa; NO gestiona sucursales, usuarios, roles
-- ni terminales (sí puede generar códigos de enrolamiento). Lista positiva a
-- propósito: un permiso nuevo no se otorga solo.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'branches.read',
    'warehouses.read',
    'users.read',
    'roles.read',
    'terminals.read', 'terminals.enroll',
    'product_categories.read', 'product_categories.manage',
    'brands.read', 'brands.manage',
    'products.read', 'products.manage',
    'customers.read', 'customers.manage',
    'suppliers.read', 'suppliers.manage',
    'purchases.read', 'purchases.manage',
    'stock.read', 'stock.adjust',
    'sales.read', 'sales.create', 'sales.void',
    'cash.read', 'cash.open', 'cash.close', 'cash.movement',
    'reports.read',
    'settings.read'
)
WHERE r.code = 'ENCARGADO'
ON CONFLICT DO NOTHING;

-- CAJERO: vender y manejar su caja; lectura de lo necesario para operar.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'product_categories.read',
    'brands.read',
    'products.read',
    'customers.read', 'customers.manage',
    'stock.read',
    'sales.read', 'sales.create',
    'cash.read', 'cash.open', 'cash.close', 'cash.movement'
)
WHERE r.code = 'CAJERO'
ON CONFLICT DO NOTHING;

-- --- Configuración del negocio (singleton) -----------------------------------
-- Fila única con valores iniciales seguros: negocio informal, IGV 18 % latente.
-- ON CONFLICT DO NOTHING: nunca pisar lo que la dueña ya configuró.

INSERT INTO business_settings (id, trade_name, receipt_footer) VALUES
    (true, 'Minimarket', '¡Gracias por su compra!')
ON CONFLICT (id) DO NOTHING;

COMMIT;
