-- =============================================================================
-- schemas.sql — Esquemas de PostgreSQL: uno por dominio del sistema.
-- Convención del proyecto: NINGUNA tabla vive en public. public queda solo
-- para extensiones y funciones de infraestructura transversal
-- (public.set_updated_at / public.set_updated_seq). Toda referencia SQL
-- (DDL, queries de sqlc, seeds) va SIEMPRE calificada esquema.tabla: nada
-- depende del search_path.
-- La numeración de archivos en tables/, triggers/ e indexes/ sigue a estos
-- dominios (01 org … 13 logs).
-- =============================================================================

CREATE SCHEMA org;
COMMENT ON SCHEMA org IS
    'Organización: configuración global del negocio (singleton), almacenes y sucursales.';

CREATE SCHEMA access;
COMMENT ON SCHEMA access IS
    'Identidad y acceso: usuarios, RBAC (roles, permisos, asignaciones) y refresh tokens de sesiones humanas.';

CREATE SCHEMA terminals;
COMMENT ON SCHEMA terminals IS
    'Terminales POS y su autenticación M2M: enrolamiento y credenciales client_credentials.';

CREATE SCHEMA catalog;
COMMENT ON SCHEMA catalog IS
    'Catálogo de productos en 3 capas (producto → presentaciones → códigos de barras), categorías y marcas. Sincroniza al POS por pull.';

CREATE SCHEMA customers;
COMMENT ON SCHEMA customers IS
    'Clientes identificados (solo para comprobantes; el negocio no fía).';

CREATE SCHEMA sales;
COMMENT ON SCHEMA sales IS
    'Ventas append-only nacidas en el POS: cabecera, líneas, pagos y comprobantes.';

CREATE SCHEMA inventory;
COMMENT ON SCHEMA inventory IS
    'Inventario: kardex (stock_movements, libro mayor del stock), conteos físicos y la vista derivada stock_levels.';

CREATE SCHEMA cash;
COMMENT ON SCHEMA cash IS
    'Caja: sesiones (turnos con apertura/cierre y arqueo) y movimientos manuales de efectivo.';

CREATE SCHEMA purchases;
COMMENT ON SCHEMA purchases IS
    'Compras de mercadería (mayorista y distribuidoras) y proveedores.';

CREATE SCHEMA sync;
COMMENT ON SCHEMA sync IS
    'Infraestructura de sincronización con las terminales: log de ingesta idempotente y el reloj lógico sync_seq del pull.';

CREATE SCHEMA reports;
COMMENT ON SCHEMA reports IS
    'Reportes generados en segundo plano: la tabla reports es a la vez estado visible al usuario y cola de trabajo (SKIP LOCKED).';

CREATE SCHEMA notifications;
COMMENT ON SCHEMA notifications IS
    'Notificaciones internas de la campanita (panel web y app móvil); no se sincronizan al POS.';

CREATE SCHEMA logs;
COMMENT ON SCHEMA logs IS
    'Telemetría HTTP de alta rotación (requests/responses), particionada por mes y con retención corta. Sin FK a propósito; excluible de backups (pg_dump --exclude-schema=logs).';
