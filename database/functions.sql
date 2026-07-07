-- =============================================================================
-- functions.sql — Funciones de infraestructura (trigger functions).
-- Regla del proyecto: los triggers son solo para infraestructura (timestamps,
-- reloj de sync); la lógica de negocio vive en Go, nunca aquí.
-- =============================================================================

-- Mantiene updated_at en cada UPDATE. Se ata con trigger BEFORE UPDATE a toda
-- tabla mutable; así ningún código puede olvidar actualizar la fecha.
CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION set_updated_at() IS
    'Trigger function: fija updated_at = now() en cada UPDATE de la fila; garantiza la fecha de última modificación sin depender de la aplicación.';


-- Avanza updated_seq en cada UPDATE de las tablas sincronizadas por pull.
-- En INSERT no hace falta trigger: la columna tiene DEFAULT nextval('sync_seq').
CREATE FUNCTION set_updated_seq() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_seq := nextval('sync_seq');
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION set_updated_seq() IS
    'Trigger function: asigna updated_seq = nextval(sync_seq) en cada UPDATE; así toda modificación queda por delante de cualquier cursor de pull ya entregado a las terminales.';
