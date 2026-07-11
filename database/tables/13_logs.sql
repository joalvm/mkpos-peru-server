-- =============================================================================
-- tables/13_logs.sql — Telemetría HTTP: log estructurado de requests/responses.
--
-- Diseño core + satélites 1:1 (partición vertical): la fila core (requests)
-- es angosta y barata de consultar; lo pesado (query, body, headers,
-- user-agent, error, respuesta) vive en tablas satélite unidas por request_id
-- y cada consulta paga solo lo que pide.
--
-- Reglas propias de este dominio (distintas del resto del esquema):
--   · TODAS las tablas van particionadas por mes: PARTITION BY RANGE
--     (created_at). La retención es DROP de partición — jamás DELETE masivo.
--     Las particiones las crea logs.ensure_partitions() (functions.sql):
--     init.sql al construir y el janitor diario del server en runtime. Por
--     exigencia de Postgres la clave de partición integra la PK, por eso las
--     PK incluyen created_at.
--   · SIN claves foráneas, ni entre satélites ni hacia otros esquemas: FK
--     contra tablas particionadas de alta escritura es puro costo; la
--     correlación es por request_id — el mismo UUID que viaja en el header
--     X-Request-Id de la respuesta y como trace_id en los errores RFC 7807.
--   · created_at se duplica en los satélites solo para alinear particiones.
--   · La redacción es del writer del server ANTES de insertar: headers
--     sensibles (authorization, cookie, set-cookie…) se eliminan, los bodies
--     de /auth/* y /enrollment JAMÁS se loguean (PLAN regla 8) y los bodies
--     grandes se truncan.
--   · Qué rutas se loguean es opt-in por ruta en el server; /health nunca.
-- =============================================================================

CREATE TABLE logs.requests (
    id           uuid        NOT NULL DEFAULT uuidv7(),
    method       text        NOT NULL,
    route        text        NOT NULL,
    path         text        NOT NULL,
    status       smallint    NOT NULL,
    duration_ms  integer     NOT NULL,
    db_ms        integer     NULL,
    ip           inet        NULL,
    subject_type text        NULL,
    subject_id   uuid        NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_requests PRIMARY KEY (id, created_at),
    CONSTRAINT ck_requests__status_range CHECK (status BETWEEN 100 AND 599),
    CONSTRAINT ck_requests__duration_non_negative CHECK (duration_ms >= 0),
    CONSTRAINT ck_requests__subject_coherence CHECK (
        (subject_type IS NULL AND subject_id IS NULL)
        OR (subject_type IN ('USER', 'TERMINAL') AND subject_id IS NOT NULL)
    )
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE logs.requests IS
    'Fila core del log de requests: una por petición HTTP logueada, con lo justo para filtrar (quién, qué ruta, status, duración). El detalle pesado vive en los satélites logs.request_* y logs.responses, unidos por request_id = id. Particionada por mes; la escribe un worker asíncrono del server (el request path jamás espera al log).';
COMMENT ON COLUMN logs.requests.id IS 'Identificador del request (UUIDv7 generado por el middleware). Es el X-Request-Id devuelto al cliente y el trace_id de los errores RFC 7807: un error reportado se busca aquí directo.';
COMMENT ON COLUMN logs.requests.method IS 'Método HTTP (GET, POST, PATCH…).';
COMMENT ON COLUMN logs.requests.route IS 'Patrón de la ruta registrada (p. ej. /api/v1/products/{id}): cardinalidad baja, ideal para agrupar y medir por endpoint.';
COMMENT ON COLUMN logs.requests.path IS 'Ruta real solicitada, con ids concretos (p. ej. /api/v1/products/0197…).';
COMMENT ON COLUMN logs.requests.status IS 'Código de estado HTTP de la respuesta.';
COMMENT ON COLUMN logs.requests.duration_ms IS 'Duración total del request en milisegundos (medida por el middleware).';
COMMENT ON COLUMN logs.requests.db_ms IS 'Milisegundos acumulados en consultas a la BD durante el request (tracer de pgx); NULL si el tracer no está activo.';
COMMENT ON COLUMN logs.requests.ip IS 'IP del cliente (considerando proxy si aplica); NULL si no se pudo determinar.';
COMMENT ON COLUMN logs.requests.subject_type IS 'Quién autenticó el request: USER (JWT humano) o TERMINAL (M2M); NULL en endpoints públicos (login, enrolamiento, health si se logueara).';
COMMENT ON COLUMN logs.requests.subject_id IS 'Id del usuario o terminal autenticado según subject_type; NULL en requests anónimos. Sin FK a propósito (regla del dominio logs).';
COMMENT ON COLUMN logs.requests.created_at IS 'Momento del request; clave de partición mensual.';


CREATE TABLE logs.request_queries (
    request_id uuid        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    query      jsonb       NOT NULL,

    CONSTRAINT pk_request_queries PRIMARY KEY (request_id, created_at)
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE logs.request_queries IS
    'Satélite 1:1 de logs.requests: query string parseada del request, solo cuando trae parámetros. Se consulta únicamente al inspeccionar un request puntual.';
COMMENT ON COLUMN logs.request_queries.request_id IS 'Request al que pertenece (= logs.requests.id); correlación sin FK.';
COMMENT ON COLUMN logs.request_queries.created_at IS 'Copia del created_at del request core, solo para alinear particiones.';
COMMENT ON COLUMN logs.request_queries.query IS 'Parámetros de la query string como objeto JSON (valores repetidos como arrays).';


CREATE TABLE logs.request_bodies (
    request_id uuid        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    body       jsonb       NULL,
    size_bytes integer     NOT NULL DEFAULT 0,
    truncated  boolean     NOT NULL DEFAULT false,

    CONSTRAINT pk_request_bodies PRIMARY KEY (request_id, created_at),
    CONSTRAINT ck_request_bodies__size_non_negative CHECK (size_bytes >= 0)
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE logs.request_bodies IS
    'Satélite 1:1 de logs.requests: body de mutaciones (POST/PATCH/PUT), ya redactado por el writer. Los bodies de /auth/* y /enrollment JAMÁS llegan aquí (PLAN regla 8); los que exceden el límite configurado se truncan con flag.';
COMMENT ON COLUMN logs.request_bodies.request_id IS 'Request al que pertenece (= logs.requests.id).';
COMMENT ON COLUMN logs.request_bodies.created_at IS 'Copia del created_at del request core, solo para alinear particiones.';
COMMENT ON COLUMN logs.request_bodies.body IS 'Body JSON del request tras la redacción; NULL si no era JSON válido (se guarda igual size_bytes).';
COMMENT ON COLUMN logs.request_bodies.size_bytes IS 'Tamaño original del body en bytes (antes de truncar).';
COMMENT ON COLUMN logs.request_bodies.truncated IS 'true = el body superó el límite del writer y se guardó recortado.';


CREATE TABLE logs.request_headers (
    request_id uuid        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    headers    jsonb       NOT NULL,

    CONSTRAINT pk_request_headers PRIMARY KEY (request_id, created_at)
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE logs.request_headers IS
    'Satélite 1:1 de logs.requests: headers del request tras aplicar la denylist del writer (authorization, cookie, x-api-key… se eliminan ANTES de insertar; aquí nunca hay secretos).';
COMMENT ON COLUMN logs.request_headers.request_id IS 'Request al que pertenece (= logs.requests.id).';
COMMENT ON COLUMN logs.request_headers.created_at IS 'Copia del created_at del request core, solo para alinear particiones.';
COMMENT ON COLUMN logs.request_headers.headers IS 'Headers como objeto JSON, ya redactados (los sensibles no se guardan).';


CREATE TABLE logs.request_agents (
    request_id uuid        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    user_agent text        NOT NULL,

    CONSTRAINT pk_request_agents PRIMARY KEY (request_id, created_at)
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE logs.request_agents IS
    'Satélite 1:1 de logs.requests: User-Agent crudo del cliente. Separado del core porque es texto largo y repetitivo que casi nunca se consulta (sirve para distinguir POS/panel/móvil y versiones al depurar).';
COMMENT ON COLUMN logs.request_agents.request_id IS 'Request al que pertenece (= logs.requests.id).';
COMMENT ON COLUMN logs.request_agents.created_at IS 'Copia del created_at del request core, solo para alinear particiones.';
COMMENT ON COLUMN logs.request_agents.user_agent IS 'Header User-Agent tal cual llegó.';


CREATE TABLE logs.request_errors (
    request_id uuid        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    code       text        NULL,
    detail     text        NULL,
    stack      text        NULL,

    CONSTRAINT pk_request_errors PRIMARY KEY (request_id, created_at)
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE logs.request_errors IS
    'Satélite 1:1 de logs.requests: detalle del error cuando el request terminó mal (status >= 400 o panic recuperado). El error RFC 7807 devuelto al cliente lleva trace_id = request_id: se busca aquí directo.';
COMMENT ON COLUMN logs.request_errors.request_id IS 'Request al que pertenece (= logs.requests.id).';
COMMENT ON COLUMN logs.request_errors.created_at IS 'Copia del created_at del request core, solo para alinear particiones.';
COMMENT ON COLUMN logs.request_errors.code IS 'Código estable del error de la API (RESOURCE_NOT_FOUND, VALIDATION_FAILED…), el mismo que viajó en la respuesta.';
COMMENT ON COLUMN logs.request_errors.detail IS 'Mensaje del error tal como se respondió (detail RFC 7807, en español).';
COMMENT ON COLUMN logs.request_errors.stack IS 'Cadena de error interna de Go (errores envueltos con %w) o stack del panic; solo se puebla fuera de requests normales de validación. Jamás contiene secretos (regla 8).';


CREATE TABLE logs.responses (
    request_id uuid        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    body       jsonb       NULL,
    size_bytes integer     NOT NULL DEFAULT 0,
    truncated  boolean     NOT NULL DEFAULT false,

    CONSTRAINT pk_responses PRIMARY KEY (request_id, created_at),
    CONSTRAINT ck_responses__size_non_negative CHECK (size_bytes >= 0)
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE logs.responses IS
    'Satélite 1:1 de logs.requests: body de la respuesta. Política por defecto del writer: solo se persiste en errores (status >= 400) — guardar cada listado exitoso sería puro peso; configurable por ruta.';
COMMENT ON COLUMN logs.responses.request_id IS 'Request al que pertenece (= logs.requests.id).';
COMMENT ON COLUMN logs.responses.created_at IS 'Copia del created_at del request core, solo para alinear particiones.';
COMMENT ON COLUMN logs.responses.body IS 'Body JSON de la respuesta (normalmente el error RFC 7807 completo); NULL si no era JSON.';
COMMENT ON COLUMN logs.responses.size_bytes IS 'Tamaño de la respuesta en bytes.';
COMMENT ON COLUMN logs.responses.truncated IS 'true = respuesta recortada por el límite del writer.';
