-- =============================================================================
-- tables/08_cash.sql — Caja: sesiones (turnos) y movimientos manuales de efectivo.
-- Las FK viven en tables/99_relations.sql.
-- =============================================================================

CREATE TABLE cash.cash_sessions (
    id               uuid        NOT NULL DEFAULT uuidv7(),
    branch_id        uuid        NOT NULL,
    terminal_id      uuid        NOT NULL,
    opened_by        uuid        NOT NULL,
    opened_at        timestamptz NOT NULL,
    opening_cents    bigint      NOT NULL,
    closed_by        uuid        NULL,
    closed_at        timestamptz NULL,
    expected_cents   bigint      NULL,
    counted_cents    bigint      NULL,
    difference_cents bigint      NULL,
    closing_note     text        NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_cash_sessions PRIMARY KEY (id),
    CONSTRAINT ck_cash_sessions__opening_non_negative CHECK (opening_cents >= 0),
    CONSTRAINT ck_cash_sessions__close_coherence CHECK (
        (closed_at IS NULL AND closed_by IS NULL AND expected_cents IS NULL
            AND counted_cents IS NULL AND difference_cents IS NULL)
        OR (closed_at IS NOT NULL AND closed_by IS NOT NULL AND expected_cents IS NOT NULL
            AND counted_cents IS NOT NULL AND difference_cents IS NOT NULL
            AND closed_at > opened_at)
    ),
    CONSTRAINT ck_cash_sessions__difference_consistent CHECK (
        difference_cents IS NULL OR difference_cents = counted_cents - expected_cents
    )
);

COMMENT ON TABLE cash.cash_sessions IS
    'Sesiones de caja (turnos) por terminal: apertura con monto inicial, ventas y movimientos durante el turno, cierre con arqueo. Esperado = apertura + Σ pagos EFECTIVO de ventas COMPLETADAS + Σ INGRESO − Σ RETIRO. Solo puede haber una sesión abierta por terminal (índice parcial).';
COMMENT ON COLUMN cash.cash_sessions.id IS 'Identificador único (UUIDv7) generado por la terminal (la caja se abre offline).';
COMMENT ON COLUMN cash.cash_sessions.branch_id IS 'Sucursal de la caja.';
COMMENT ON COLUMN cash.cash_sessions.terminal_id IS 'Terminal donde se abrió la sesión.';
COMMENT ON COLUMN cash.cash_sessions.opened_by IS 'Usuario que abrió la caja.';
COMMENT ON COLUMN cash.cash_sessions.opened_at IS 'Momento de apertura según la terminal.';
COMMENT ON COLUMN cash.cash_sessions.opening_cents IS 'Efectivo inicial declarado al abrir (sencillo para el vuelto), en céntimos.';
COMMENT ON COLUMN cash.cash_sessions.closed_by IS 'Usuario que cerró la caja; NULL mientras esté abierta.';
COMMENT ON COLUMN cash.cash_sessions.closed_at IS 'Momento de cierre; NULL = sesión abierta.';
COMMENT ON COLUMN cash.cash_sessions.expected_cents IS 'Efectivo que debería haber al cierre según la fórmula del arqueo (snapshot calculado al cerrar).';
COMMENT ON COLUMN cash.cash_sessions.counted_cents IS 'Efectivo contado físicamente por el cajero al cerrar.';
COMMENT ON COLUMN cash.cash_sessions.difference_cents IS 'Descuadre = contado − esperado (CHECK); negativo = falta plata, positivo = sobra.';
COMMENT ON COLUMN cash.cash_sessions.closing_note IS 'Observación libre del cierre (explicación del descuadre, incidencias).';
COMMENT ON COLUMN cash.cash_sessions.created_at IS 'Fecha de inserción del registro en el servidor.';
COMMENT ON COLUMN cash.cash_sessions.updated_at IS 'Fecha de última modificación (cambia al cerrar; mantenida por trigger).';


CREATE TABLE cash.cash_movements (
    id              uuid               NOT NULL DEFAULT uuidv7(),
    cash_session_id uuid               NOT NULL,
    type            cash.cash_movement_type NOT NULL,
    amount_cents    bigint             NOT NULL,
    reason          text               NOT NULL,
    user_id         uuid               NOT NULL,
    occurred_at     timestamptz        NOT NULL,
    created_at      timestamptz        NOT NULL DEFAULT now(),

    CONSTRAINT pk_cash_movements PRIMARY KEY (id),
    CONSTRAINT ck_cash_movements__amount_positive CHECK (amount_cents > 0)
);

COMMENT ON TABLE cash.cash_movements IS
    'Movimientos manuales de efectivo dentro de una sesión de caja (ingresos y retiros con motivo). Las ventas NO van aquí: entran al arqueo vía payments. Inmutable: un error se corrige con el movimiento contrario.';
COMMENT ON COLUMN cash.cash_movements.id IS 'Identificador único (UUIDv7) generado por la terminal.';
COMMENT ON COLUMN cash.cash_movements.cash_session_id IS 'Sesión de caja afectada.';
COMMENT ON COLUMN cash.cash_movements.type IS 'INGRESO suma al efectivo esperado; RETIRO resta.';
COMMENT ON COLUMN cash.cash_movements.amount_cents IS 'Monto del movimiento en céntimos; siempre positivo (el sentido lo da type).';
COMMENT ON COLUMN cash.cash_movements.reason IS 'Motivo obligatorio (p. ej. "pago a proveedor", "retiro de la dueña").';
COMMENT ON COLUMN cash.cash_movements.user_id IS 'Usuario que registró el movimiento.';
COMMENT ON COLUMN cash.cash_movements.occurred_at IS 'Momento real del movimiento según el reloj de la terminal (nace offline); created_at solo dice cuándo lo insertó el servidor.';
COMMENT ON COLUMN cash.cash_movements.created_at IS 'Fecha de inserción del registro en el servidor.';
