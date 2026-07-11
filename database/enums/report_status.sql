-- Estado del ciclo de vida de un reporte generado en segundo plano. El usuario
-- lo solicita (POST /reports → 202), un worker del propio binario API toma la
-- fila PENDIENTE más antigua con FOR UPDATE SKIP LOCKED, la genera y publica
-- el archivo; el usuario consulta el estado y descarga al ver COMPLETADO.
CREATE TYPE reports.report_status AS ENUM (
    'PENDIENTE',    -- encolado: ningún worker lo tomó todavía
    'EN_PROCESO',   -- un worker lo está generando
    'COMPLETADO',   -- archivo listo para descargar (columnas file_* pobladas)
    'FALLIDO'       -- la generación falló (error poblado); no se reintenta la fila: se solicita un reporte nuevo
);

COMMENT ON TYPE reports.report_status IS
    'Ciclo de vida de un reporte en segundo plano: PENDIENTE → EN_PROCESO → COMPLETADO | FALLIDO. La tabla reports.reports es su propia cola de trabajo.';
