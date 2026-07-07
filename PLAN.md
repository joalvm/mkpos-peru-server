# PLAN server — API central Go (para IA ejecutora)

Estilo: telegráfico a propósito. Ejecuta en orden. No inventes fuera de esto.
Verdad del proyecto: `../docs/PROYECTO.md` (checkout hermano). Léelo antes: § 2, 4, 5, 6, 7.
Esquema BD YA existe y es intocable sin actualizar PROYECTO.md § 6: `database/` (init.sql orquesta).

## Reglas duras (violarlas = trabajo rechazado)

1. API solo aditiva. Nunca renombrar/eliminar campo publicado.
2. Identificadores inglés; valores enum español (`EFECTIVO`, `MERMA`); comentarios/errores de usuario español.
3. Dinero `int64` céntimos. Jamás float para dinero. Cantidades: decimal 3 posiciones (pgtype.Numeric / shopspring vía sqlc override).
4. Secrets jamás en claro en BD ni logs: argon2id (passwords, PIN, client_secret), SHA-256 (refresh tokens, enrollment codes).
5. Nada de ORM. sqlc + pgx. SQL a mano en `db/queries/`.
6. Stock/dinero derivados de eventos. Prohibido UPDATE directo de saldos.
7. Lógica de negocio en Go (`internal/domain`), no en triggers/SPs.
8. Commits: Conventional Commits, descripción español.

## Stack fijo

Go 1.26+ · huma v2 (router: chi v5) · pgx v5 + sqlc · golang-jwt/jwt v5 (EdDSA ed25519) ·
golang.org/x/crypto/argon2 · koanf (config env) · log/slog · Taskfile (go-task) · air (dev reload) ·
golangci-lint · PostgreSQL 18 en docker compose (solo dev).

## Estructura objetivo

```
server/
├── cmd/api/main.go            # wire: config → pool → stores → api → listen
├── cmd/hashgen/main.go        # CLI dev: genera hashes argon2id para seeds
├── internal/
│   ├── config/                # koanf: env MKPOS_* (.env dev)
│   ├── api/                   # huma: registro rutas, handlers por dominio, middleware
│   ├── auth/                  # jwt emit/verify, argon2, refresh rotation, m2m
│   ├── domain/                # lógica pura testeable: totales, arqueo, redondeo, transiciones
│   ├── store/                 # generado por sqlc (no editar a mano)
│   └── sync/                  # push: apply por event_type; pull: builder de snapshot/deltas
├── db/queries/*.sql           # fuente sqlc, un archivo por dominio
├── database/                  # esquema (ya existe)
├── docker-compose.yml         # solo dev: postgres:18-alpine
├── Taskfile.yml
├── sqlc.yaml
├── .env.example
└── openapi.yaml               # GENERADO por huma; SE COMMITEA (contrato para apps)
```

## Tareas en orden

### T1 — Bootstrap
`go mod init github.com/mkpos-peru/server`. Deps arriba. `docker-compose.yml`:
servicio `db` postgres:18-alpine, user/db `mkpos`, password dev `mkpos`, puerto 5432,
volumen pgdata + `./database:/database:ro`, healthcheck pg_isready.
`.env.example`: `MKPOS_DATABASE_URL`, `MKPOS_JWT_PRIVATE_KEY` (ed25519 base64, vacío = autogenera en dev a `.jwtkey` gitignored), `MKPOS_ADDR=:8080`.
Taskfile: `setup`, `dev` (air), `build`, `test`, `lint`, `db:reset`, `db:seed:dev`, `db:psql`, `generate`.
`db:reset` = `docker compose exec -T db psql -U mkpos -d mkpos -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'` → `... -f /database/init.sql` → `... -f /database/seeds/system.sql`.
DoD: `task db:reset` verde desde cero; `/health` responde `{"status":"ok"}` con ping a BD.

### T2 — sqlc
`sqlc.yaml`: engine postgresql, schema `database/` (init + tables + enums; sqlc lee DDL),
queries `db/queries/`, out `internal/store`, sql_package pgx/v5, emit_json_tags false.
Overrides: uuid → `github.com/google/uuid`, numeric → `github.com/shopspring/decimal` (via sqlc plugin config estándar).
DoD: `task generate` produce `internal/store` compilable con una query smoke (GetBranch).

### T3 — Seeds dev
`cmd/hashgen`: `hashgen "texto"` → hash argon2id (parámetros: t=3, m=64MB, p=2; mismos en auth).
`database/seeds/dev.sql` (idempotente, `ON CONFLICT`): 2 branches (S01 "Centro", S02 "Norte");
usuarios: `admin` PROPIETARIO global (password `Admin123!`, pin `9999`), `encargado1` ENCARGADO S01
(password `Encargado123!`, pin `1111`), `cajero1`/`cajero2` CAJERO S01 (solo pin `1234`/`5678`);
hashes precomputados con hashgen, plaintext documentado en comentario SQL (solo dev).
8 categorías, ~40 productos realistas de minimarket piurano (mezcla: barcode UNIDAD, granel KG arroz/azúcar/menestras,
aceite L, gaseosas, DOCENA huevos; precios céntimos realistas; min_stock en algunos).
3 suppliers (Alvarez Bohl RUC, Kompass RUC, "Mercado mayorista" sin RUC).
1 terminal T01 por branch (PENDIENTE). 2 customers (DNI, RUC).
1 purchase MAYORISTA RECIBIDA por branch con items → stock_movements COMPRA correspondientes (stock inicial coherente).
DoD: `task db:reset && task db:seed:dev` verde; `SELECT * FROM stock_levels` con datos.

### T4 — Núcleo HTTP
huma v2 sobre chi. Versionado `/api/v1`. Middleware: request-id, slog logging, recover, CORS (dev abierto, config).
Errores RFC 7807 (huma default), mensajes `detail` en español.
`GET /api/v1/health`. Config CORS/addr por env.
DoD: arranca, huma genera OpenAPI en `/openapi.yaml`; task `generate` lo vuelca a `./openapi.yaml` y commitea.

### T5 — Auth humanos
Endpoints:
- `POST /api/v1/auth/login` {username, password} → {access_token, refresh_token, user, permissions[]}. Verifica argon2id, user activo.
- `POST /api/v1/auth/refresh` {refresh_token} → par nuevo. Rotación: marca viejo revoked_at + replaced_by_id. **Reuso de token ya rotado = robo: revoca TODA la cadena del usuario y 401.**
- `POST /api/v1/auth/logout` {refresh_token} → revoca.
- `GET /api/v1/auth/me` → user + permissions.
Access JWT EdDSA 15 min, claims: `sub` (user id), `typ:"user"`. Refresh: 256 bits random base64url, BD solo SHA-256, expira 30 d.
Permisos NO van en el JWT (revocación inmediata > tamaño): middleware consulta BD por request (escala sobra).
Middleware `RequireUser`, `RequirePermission(code)`: permiso vía user_roles→role_permissions; scope: branch_id del recurso o global (user_roles.branch_id NULL).
DoD: tests integración: login ok/fail, refresh rota, reuso revoca cadena, permiso denegado 403.

### T6 — Auth terminales (M2M)
- `POST /api/v1/terminals` (terminals.manage) {branch_id, code, name} → PENDIENTE.
- `POST /api/v1/terminals/{id}/enrollment-codes` (terminals.enroll) → code `XXXX-XXXX-XXXX` (A-Z2-9 sin ambiguos, crypto/rand), respuesta lo muestra UNA vez, BD guarda SHA-256, expira 72 h.
- `POST /api/v1/enrollment` (sin auth, rate-limited) {code} → valida hash+vigencia+no usado → genera client_id (`term_` + uuid) y client_secret (256 bits), guarda argon2id, marca used_at, terminal ACTIVO → {client_id, client_secret, terminal, branch} UNA vez.
- `POST /api/v1/auth/token` {grant_type:"client_credentials", client_id, client_secret} → access JWT 15 min claims `sub`=terminal_id, `typ:"terminal"`, `branch_id`. Rechaza si terminal ≠ ACTIVO o credencial revocada. Actualiza last_used_at/last_seen_at.
- `POST /api/v1/terminals/{id}/revoke` (terminals.manage) → REVOCADO + revoca credenciales.
Middleware `RequireTerminal`.
DoD: test flujo completo enrolamiento → token → endpoint sync; código reusado falla; terminal revocada 401.

### T7 — CRUD administración
Todos bajo `RequireUser` + permiso indicado. Paginación cursor `?limit&after`, filtros básicos.
| Recurso | Rutas | Permiso |
|---|---|---|
| branches | GET/POST/PATCH `/branches` | read / manage |
| users | GET/POST/PATCH `/users` + PUT `/users/{id}/roles` | users.read / users.manage |
| roles | GET/POST/PATCH `/roles` + PUT `/roles/{id}/permissions`; GET `/permissions` | roles.* |
| terminals | GET `/terminals` (+T6) | terminals.read |
| categories | GET/POST/PATCH `/categories` | categories.* |
| products | GET/POST/PATCH `/products`; GET `/products?q=` (trgm) `&barcode=` | products.* |
| customers | GET/POST/PATCH `/customers` (búsqueda por doc) | customers.* |
| suppliers | GET/POST/PATCH `/suppliers` | suppliers.* |
Soft delete = PATCH is_active:false. Sin DELETE físico en ningún recurso.
DoD: tests por recurso: crear, validación 422, permiso 403, unique 409.

### T8 — Compras y stock
- `POST /purchases` (purchases.manage): kind MAYORISTA → nace RECIBIDA con items, misma tx crea stock_movements COMPRA (+qty, purchase_item_id) y fija received_at; kind DISTRIBUIDORA → nace PEDIDA (ordered_at obligatorio), sin stock.
- `POST /purchases/{id}/receive`: PEDIDA→RECIBIDA, crea movimientos COMPRA. `POST /purchases/{id}/cancel`: PEDIDA→CANCELADA. Transiciones inválidas 409.
- `total_cents` = Σ items (calcula servidor, rechaza mismatch del cliente).
- `GET /stock?branch_id=` (stock_levels + producto + bajo mínimo flag). `GET /products/{id}/kardex?branch_id=`.
- `POST /stock/adjustments` (stock.adjust) {branch_id, product_id, type AJUSTE|MERMA, quantity, reason} → stock_movement directo (signos: CHECK de BD manda).
DoD: tests: mayorista ingresa stock atómico; receive idempotente-no (segunda vez 409); merma sin reason 422.

### T9 — Ventas y caja (lectura + reportes)
Ventas NACEN en el POS y llegan por sync (T10). Aquí solo lectura/reportes.
Anulación TAMBIÉN nace en el POS (offline-first; el encargado anula en tienda). Admin no anula en F1.
- `GET /sales?branch_id&from&to&status&terminal_id` (sold_on_local), `GET /sales/{id}` (items+payments+document).
- `GET /cash-sessions?branch_id&from&to`, `GET /cash-sessions/{id}` (movs + ventas EFECTIVO + fórmula arqueo).
- Reportes (reports.read): `GET /reports/sales-daily?from&to&branch_id` (Σ por sold_on_local),
  `GET /reports/top-products?from&to&branch_id&limit`, `GET /reports/cash-differences?from&to`,
  `GET /reports/margin?from&to` (venta − costo referencial cost_cents; aproximado, documentado).
`internal/domain`: fórmula arqueo única: `expected = opening + Σ payments EFECTIVO (ventas COMPLETADAS) + Σ INGRESO − Σ RETIRO`.
DoD: tests domain arqueo (casos: sin ventas, con anuladas excluidas, con retiros); reportes con seeds dev cuadran a mano.

### T10 — Sync push (idempotente)
`POST /api/v1/sync/push` (RequireTerminal) body `{events: [{event_id uuid, event_type, occurred_at, payload}]}` máx 100.
Respuesta por evento: `{event_id, status: "applied"|"duplicate"|"error", message?}`.
Por evento, UNA tx: `INSERT sync_ingest_log ON CONFLICT (event_id) DO NOTHING` → 0 filas = duplicate, corta.
Aplica según event_type (payload versionado `{"v":1,...}`):
- `sale.created`: inserta sale (id del POS) + items + payments + document + stock_movements VENTA (−qty por item, sale_item_id). Valida: total = Σ items − discount, Σ payments = total, cash_session existe abierta o cerrada de esa terminal, terminal/branch del JWT coinciden.
- `sale.voided`: sale → ANULADA (voided_*) + movimientos ANULACION_VENTA espejo (+qty).
- `cash_session.opened`: inserta sesión (id del POS).
- `cash_session.closed`: fija cierre; recalcula expected server-side con domain y compara con el declarado → difieren = aplica igual pero loggea WARN (reloj/atraso), guarda lo del POS (verdad local).
- `cash_movement.created`, `stock.adjusted` (AJUSTE/MERMA desde POS por encargado).
Error de validación → status "error" + NO inserta en ingest_log (deja reintentar tras fix) — EXCEPTO violación de integridad permanente: marca applied-with-error en log WARN y responde "error" message claro.
Orden dentro del batch se respeta (secuencial). Actualiza terminals.last_seen_at.
DoD: tests: mismo evento 2 veces → duplicate sin doble stock; batch con 1 malo no rompe los demás; venta cruza terminal ajena → 403/error.

### T11 — Sync pull
`GET /api/v1/sync/pull?cursor=N` (RequireTerminal) →
```
{ cursor: M,                                  // max updated_seq entregado
  branches[], users[],                        // users: id, full_name, username, pin_hash, is_active, updated_seq (JAMÁS password_hash)
  categories[], products[], customers[],      // filas con updated_seq > N
  rbac: {roles[], permissions[], role_permissions[], user_roles[]} }  // snapshot COMPLETO siempre (tablas chicas, evita tombstones)
```
Límite por tabla 500 filas + flag `has_more` (POS re-pide). Filtrado: todo global (multi-sucursal chica; afinar después será aditivo).
DoD: test: editar producto → aparece en pull con cursor viejo, no con nuevo; pin cambiado llega; rbac siempre completo.

### T12 — Endurecimiento
Rate limit `/auth/login`, `/auth/token`, `/enrollment` (por IP, memoria). Timeouts servidor. `task lint` limpio.
README server actualizado (comandos reales). openapi.yaml regenerado y commiteado.
DoD: `task test` y `task lint` verdes; checklist PROYECTO.md § 9 cumplido.

## Definición de hecho global
`task db:reset && task db:seed:dev && task test && task lint` todo verde desde clon limpio +
`docker compose up -d`. openapi.yaml commiteado refleja TODOS los endpoints.
