-- =============================================================================
-- functions.sql — Funciones de infraestructura (trigger functions).
-- Regla del proyecto: los triggers son solo para infraestructura (timestamps,
-- reloj de sync); la lógica de negocio vive en Go, nunca aquí.
-- =============================================================================

-- Mantiene updated_at en cada UPDATE. Se ata con trigger BEFORE UPDATE a toda
-- tabla mutable; así ningún código puede olvidar actualizar la fecha.
CREATE FUNCTION public.set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_updated_at() IS
    'Trigger function: fija updated_at = now() en cada UPDATE de la fila; garantiza la fecha de última modificación sin depender de la aplicación.';


-- Avanza updated_seq en cada UPDATE de las tablas sincronizadas por pull.
-- En INSERT no hace falta trigger: la columna tiene DEFAULT nextval('sync.sync_seq').
CREATE FUNCTION public.set_updated_seq() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_seq := nextval('sync.sync_seq');
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_updated_seq() IS
    'Trigger function: asigna updated_seq = nextval(sync_seq) en cada UPDATE; así toda modificación queda por delante de cualquier cursor de pull ya entregado a las terminales.';


-- Crea por adelantado las particiones mensuales de TODAS las tablas del
-- esquema logs (mes actual + months_ahead siguientes). Idempotente: las que
-- ya existen se saltan. La llama init.sql al construir la BD y el janitor
-- diario del server en runtime. Nomenclatura: <tabla>_YYYYMM.
CREATE FUNCTION logs.ensure_partitions(months_ahead integer DEFAULT 1) RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    log_tables CONSTANT text[] := ARRAY[
        'requests', 'request_queries', 'request_bodies', 'request_headers',
        'request_agents', 'request_errors', 'responses'];
    tbl        text;
    m          integer;
    month_from date;
    part_name  text;
    created    integer := 0;
BEGIN
    FOR m IN 0..months_ahead LOOP
        month_from := (date_trunc('month', now()) + make_interval(months => m))::date;
        FOREACH tbl IN ARRAY log_tables LOOP
            part_name := format('%s_%s', tbl, to_char(month_from, 'YYYYMM'));
            IF to_regclass(format('logs.%I', part_name)) IS NULL THEN
                EXECUTE format(
                    'CREATE TABLE logs.%I PARTITION OF logs.%I FOR VALUES FROM (%L) TO (%L)',
                    part_name, tbl, month_from, (month_from + interval '1 month')::date);
                created := created + 1;
            END IF;
        END LOOP;
    END LOOP;
    RETURN created;
END;
$$;

COMMENT ON FUNCTION logs.ensure_partitions(integer) IS
    'Crea las particiones mensuales que falten en todas las tablas del esquema logs (mes actual + N siguientes) y devuelve cuántas creó. Idempotente; la llaman init.sql y el janitor diario del server.';


-- Borra las particiones del esquema logs más viejas que la retención pedida.
-- Borrar una partición es O(1) (DROP TABLE), jamás un DELETE masivo. La
-- retención por defecto la define el server (MKPOS_LOGS_RETENTION_MONTHS).
CREATE FUNCTION logs.drop_partitions_older_than(retention_months integer) RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    cutoff  date := (date_trunc('month', now()) - make_interval(months => retention_months))::date;
    part    record;
    dropped integer := 0;
BEGIN
    FOR part IN
        SELECT c.relname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'logs'
          AND c.relispartition
          AND c.relname ~ '_[0-9]{6}$'
          AND to_date(right(c.relname, 6) || '01', 'YYYYMMDD') < cutoff
    LOOP
        EXECUTE format('DROP TABLE logs.%I', part.relname);
        dropped := dropped + 1;
    END LOOP;
    RETURN dropped;
END;
$$;

COMMENT ON FUNCTION logs.drop_partitions_older_than(integer) IS
    'Aplica la retención de la telemetría: DROP de toda partición mensual del esquema logs anterior a (mes actual − retention_months); devuelve cuántas borró. La llama el janitor diario del server.';
