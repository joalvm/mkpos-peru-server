-- =============================================================================
-- sequences.sql — Secuencias globales.
-- =============================================================================

-- Reloj lógico global de sincronización. Toda tabla que las terminales POS
-- descargan por pull incremental tiene una columna updated_seq que toma su
-- valor de esta secuencia (DEFAULT en INSERT, trigger en UPDATE). El pull se
-- hace con cursor: "dame todo lo que tenga updated_seq > mi último cursor".
CREATE SEQUENCE sync.sync_seq AS bigint;

COMMENT ON SEQUENCE sync.sync_seq IS
    'Reloj lógico global de sincronización: alimenta las columnas updated_seq de las tablas que el POS descarga por pull incremental con cursor.';
