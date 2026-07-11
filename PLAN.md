# PLAN server — API central Go (para IA ejecutora)

Telegráfico a propósito. Ejecuta en orden T1→T15 (T16-T17 diferidas a F2+,
ver INDEX). Protocolo obligatorio e
invariantes (redondeo, contrato sync, formatos JSON): `../docs/plans/INDEX.md`.
Verdad del proyecto: `../docs/PROYECTO.md` §§ 2, 4, 5, 6, 7 — leer ANTES de T1.
Esquema BD YA existe, validado, intocable sin actualizar PROYECTO.md § 6:
`database/` (init.sql orquesta; seeds/system.sql siempre; seeds/dev.sql la crea T3).

## Reglas duras (violarlas = trabajo rechazado)

1. API solo aditiva. Nunca renombrar/eliminar campo o endpoint publicado.
2. Identificadores inglés; valores enum español (`EFECTIVO`, `MERMA`); mensajes de error al usuario y comentarios en español.
3. Dinero `int64` céntimos, jamás float. Cantidades `decimal` 3 posiciones (shopspring/decimal vía override sqlc). En JSON: dinero integer, cantidad string "2.500".
4. Hashes: argon2id (passwords, PIN, client_secret; params t=3, m=64MiB, p=2, salt 16, key 32 — constantes en `internal/auth`), SHA-256 (refresh tokens, enrollment codes — tokens de alta entropía no necesitan KDF).
5. Nada de ORM. sqlc + pgx. SQL a mano en `db/queries/`. Prohibido SQL en handlers.
6. Stock/dinero derivados de eventos. Prohibido UPDATE de saldos. Correcciones = movimiento nuevo.
7. Lógica de negocio en `internal/domain` (puro, sin deps http/store), no en triggers/SPs.
8. Jamás loggear: passwords, PINs, tokens, secrets, hashes, cuerpos de /auth. Request-id sí.
9. Toda ruta declara su permiso o su tipo de auth. Cero endpoints "abiertos" salvo /health y /enrollment (rate-limited).
10. Errores wrapped `%w` con contexto. RFC 7807 hacia fuera, `detail` en español.
11. Esquemas por dominio (PROYECTO § 6): TODA referencia SQL calificada `esquema.tabla` (`org.branches`, `sales.sales`) — DDL, queries sqlc y seeds; nada de search_path. En `public` solo extensiones y funciones infra.
12. Respuestas según INDEX: paginación `?page=&per_page=` + meta Laravel-style; listados acotados = array pelado (decisión día 1, JAMÁS muta); errores RFC 7807 + extensiones `code`/`trace_id`/`errors[]`/`debug`(solo dev).

## Stack fijo

Go 1.26+ · huma v2 (router chi v5) · pgx v5 + sqlc · golang-jwt/jwt v5 (EdDSA ed25519) ·
golang.org/x/crypto/argon2 · shopspring/decimal · koanf (env `MKPOS_*`) · log/slog (JSON) ·
Taskfile (go-task) · air (dev) · golangci-lint · testcontainers-go o compose-db para tests de integración
(elige compose-db: la BD de docker compose ya está; tests usan schema propio por corrida) ·
PostgreSQL 18 (docker compose SOLO dev).

## Estructura objetivo

```
server/
├── cmd/api/main.go            # wire: config → pool → stores → api → listen (graceful shutdown)
├── cmd/hashgen/main.go        # CLI dev: argon2id/sha256 para seeds
├── internal/
│   ├── config/                # koanf: MKPOS_DATABASE_URL, MKPOS_ADDR, MKPOS_JWT_PRIVATE_KEY,
│   │                          # MKPOS_CORS_ORIGINS, MKPOS_COOKIE_SECURE, MKPOS_ENV (dev|prod)
│   ├── api/                   # huma: register por dominio, middleware (auth, rbac, ratelimit, logging)
│   ├── auth/                  # argon2, jwt emit/verify (iss=mkpos-server, aud=mkpos-api, kid),
│   │                          # refresh rotation, lockout, m2m client_credentials
│   ├── domain/                # PURO: redondeo, arqueo, igv, transiciones purchase, validación venta
│   ├── store/                 # GENERADO por sqlc — no editar
│   ├── sync/                  # push: apply por event_type (una tx c/u); pull: snapshot/deltas
│   ├── requestlog/            # T13: middleware + writer async → esquema logs; janitor de particiones
│   ├── notify/                # T16 (diferida): campanita — fanout a notifications.notifications
│   ├── reports/               # T17 (diferida): registro de kinds + workers SKIP LOCKED
│   └── storage/               # T17 (diferida): archivos generados; v1 disco (MKPOS_STORAGE_DIR)
├── db/queries/*.sql           # fuente sqlc: un archivo por dominio (branches.sql, sales.sql…)
├── database/                  # esquema (existe) + seeds/dev.sql (T3)
├── docker-compose.yml         # SOLO dev: postgres:18-alpine
├── Taskfile.yml · sqlc.yaml · .env.example · .golangci.yml
├── postman/                   # GENERADO: task api:postman (colección por dominio + environment)
└── openapi.yaml               # GENERADO por huma; SE COMMITEA (contrato para apps)
```

## Mapa endpoints (todos bajo /api/v1; permiso entre paréntesis)

```
GET  /health                                  (público; ping BD)
POST /auth/login                              (público, rate-limit IP+username)
POST /auth/refresh                            (cookie mkpos_rt O body {refresh_token} — mobile)
POST /auth/logout                             (revoca refresh presentado)
GET  /auth/me                                 (RequireUser → user+roles+permissions)
POST /auth/token                              (M2M client_credentials, rate-limit)
POST /enrollment                              (público, rate-limit fuerte, canjea código)
GET/POST/PATCH /branches[,/{id}]              (branches.read / branches.manage)
GET/POST/PATCH /warehouses[,/{id}]            (warehouses.read / warehouses.manage)
GET/POST/PATCH /users[,/{id}]                 (users.read / users.manage)
PUT  /users/{id}/roles                        (users.manage; reemplaza set user_roles)
POST /users/{id}/reset-password|reset-pin     (users.manage; genera temporal/valida formato)
GET/POST/PATCH /roles[,/{id}]                 (roles.read / roles.manage; is_system solo lectura)
PUT  /roles/{id}/permissions                  (roles.manage)
GET  /permissions                             (roles.read)
GET/POST/PATCH /terminals[,/{id}]             (terminals.read / terminals.manage)
POST /terminals/{id}/enrollment-codes         (terminals.enroll; invalida código previo no usado)
POST /terminals/{id}/revoke                   (terminals.manage; REVOCADO + revoca credenciales)
GET/POST/PATCH /product-categories[,/{id}]    (product_categories.*)
GET/POST/PATCH /brands[,/{id}]                (brands.*)
GET/POST/PATCH /products[,/{id}]              (products.*; GET ?q= trgm, ?barcode= vía
                                               product_barcodes, ?category_id=, ?brand_id=;
                                               detail embebe presentations + barcodes)
GET  /products/barcode-lookup?barcode=        (products.manage; proxy Open Food Facts)
POST/PATCH /products/{id}/presentations[,/{pid}]                 (products.manage)
POST/PATCH /products/{id}/presentations/{pid}/barcodes[,/{bid}]  (products.manage)
GET/POST/PATCH /customers[,/{id}]             (customers.*; GET ?doc= búsqueda exacta)
GET/POST/PATCH /suppliers[,/{id}]             (suppliers.*)
GET  /settings · PATCH /settings              (settings.read / settings.manage)
GET/POST /purchases · GET /purchases/{id}     (purchases.*)
POST /purchases/{id}/receive|/cancel          (purchases.manage; transición inválida = 409)
GET  /stock?branch_id=|warehouse_id=&low=     (stock.read; desde stock_levels + join products)
GET  /products/{id}/kardex?warehouse_id=&from=&to=  (stock.read)
POST /stock/adjustments                       (stock.adjust; AJUSTE|MERMA server-side)
GET/POST /inventory-counts · GET /inventory-counts/{id}   (stock.read / stock.adjust)
PUT  /inventory-counts/{id}/items             (stock.adjust; upsert counted_qty)
POST /inventory-counts/{id}/apply|/cancel     (stock.adjust; genera AJUSTEs / cancela)
GET  /sales?branch_id&from&to&status&terminal_id · GET /sales/{id}  (sales.read)
GET  /cash-sessions?branch_id&from&to · GET /cash-sessions/{id}     (cash.read)
GET  /reports/sales-daily|top-products|cash-differences|margin      (reports.read)
POST /sync/push · GET /sync/pull?cursor=      (RequireTerminal, scopes sync)
POST/GET /reports · GET /reports/{id}[,/download]  (reports.read; T17 — exports pesados async; los 4 reportes de T9 SIGUEN síncronos)
GET  /notifications?unread_only= · GET /notifications/unread-count   (RequireUser; T16 — cada quien SOLO las suyas)
POST /notifications/{id}/read · POST /notifications/read-all         (RequireUser; T16)
```

Paginación listados: `?page=&per_page=` (default 50, máx 200) →
`{data, meta:{per_page, current_page, from, to, last_page, total}}`.
Listados acotados = array pelado SIN envelope, SOLO: branches, warehouses,
roles, permissions, product-categories, terminals (la forma por endpoint se
decide día 1 y JAMÁS muta — INDEX). El pull de sync mantiene su cursor.
Soft delete = PATCH `is_active:false`. Sin DELETE físico en ningún recurso.

## Tareas

### T1 — Bootstrap
`go mod init github.com/mkpos-peru/server`. docker-compose.yml: servicio `db`
postgres:18-alpine, user/pass/db `mkpos`, puerto 5432, volumen pgdata +
`./database:/database:ro`, healthcheck pg_isready. `.env.example` con todas las
MKPOS_* documentadas (JWT key vacía = autogenerar en dev a `.jwtkey` gitignored).
Taskfile: `setup`, `dev` (air), `build`, `test`, `lint`, `db:reset`, `db:seed:dev`,
`db:psql`, `generate`. `db:reset` = drop CASCADE de los 13 esquemas de dominio (org…logs) + public,
recrear public → `psql -f /database/init.sql` → `-f /database/seeds/system.sql`.
.gitignore (bin, .env, .jwtkey). .golangci.yml estándar estricto.
DoD: `docker compose up -d && task db:reset` verde desde clon; `task lint` verde.

### T2 — sqlc
sqlc.yaml: engine postgresql; schema = `database/` (lee DDL completo); queries
`db/queries/`; out `internal/store`; sql_package pgx/v5; overrides: uuid →
google/uuid, numeric → shopspring/decimal. Queries SIEMPRE calificadas
`esquema.tabla` (regla 11): sqlc resuelve lo no calificado contra public,
donde no hay tablas. Query smoke `GetBranch` (org.branches) + main
mínimo `/health` (huma sobre chi, ping pool).
DoD: `task generate` produce store compilable; `curl /health` → `{"status":"ok"}`.

### T3 — Seeds dev
`cmd/hashgen`: `hashgen argon2 "texto"` / `hashgen sha256 "texto"`.
`database/seeds/dev.sql` idempotente (ON CONFLICT DO NOTHING, ids fijos UUIDv7
literales para reproducibilidad):
- warehouses PRIMERO (branches.warehouse_id NOT NULL): A-S01, A-S02 → luego
  2 branches S01 "Centro" (→A-S01), S02 "Norte" (→A-S02).
- users: `admin` PROPIETARIO global (pass `Admin123!`, pin `9999`), `encargado1`
  ENCARGADO@S01 (pass `Encargado123!`, pin `1111`), `cajero1`/`cajero2`
  CAJERO@S01 (solo pin `1234`/`5678`). Hashes precomputados; plaintext en
  comentario SQL (solo dev).
- 8 product_categories + ~6 brands (Coca-Cola, Gloria, Costeño, Laive, San
  Fernando, Alicorp); ~40 productos minimarket piurano en 3 capas: cada
  producto con presentación base (factor 1, default venta) + barcode donde
  aplique; gaseosa con presentaciones extra Six-pack ×6 (vendible, barcode
  propio) y Caja ×24 (solo compra, barcode propio); granel KG (arroz, azúcar,
  menestras — tax_affectation EXONERADO donde aplique: frutas/verduras
  frescas), aceite L, huevos presentación "Docena" factor 12 (enum DOCENA ya
  no existe), 1 producto is_open_price "VARIOS" (precio 0), bolsa
  icbper_applies=true; min_stock en ~10.
- 3 suppliers (Alvarez Bohl RUC, Kompass RUC, "Mercado mayorista" sin RUC).
- 1 terminal por branch, code GLOBAL único `S01-T01`, `S02-T01` (PENDIENTE).
- 2 customers (DNI, RUC). 1 purchase MAYORISTA RECIBIDA por branch con items
  POR PRESENTACIÓN (caja ×24 gaseosa, saco ×50 arroz) → stock_movements COMPRA
  en unidad base (qty × factor; warehouse de la branch, occurred_at = received_at).
DoD: `task db:reset && task db:seed:dev` verde; `SELECT * FROM stock_levels`
devuelve filas con branch_id y warehouse_id coherentes.

### T4 — Núcleo HTTP
huma v2 + chi. Versionado `/api/v1`. Middleware en orden: request-id → slog
(método, ruta, status, dur, request-id; NUNCA bodies de auth) → recover →
CORS (origins de config; en dev `*`) → timeouts (read 10s, write 30s, idle 120s).
Errores RFC 7807 huma con extensiones (regla 12): `code` estable por tipo,
`trace_id` = request-id (header `X-Request-Id` en TODA respuesta), `errors[]`
de huma en validación, `debug` (trace) solo `MKPOS_ENV=dev`; `detail`
español. Graceful shutdown (SIGTERM, drain 15s).
`task generate` vuelca openapi a `./openapi.yaml` (composición: arranca server
en modo export o usa huma CLI API) y se commitea. Tags de huma por dominio
(los usa el export Postman). `task api:postman`: `npx openapi-to-postmanv2
-s openapi.yaml -o postman/mkpos.postman_collection.json -O
folderStrategy=Tags` + environment con {{base_url}}, {{access_token}},
{{terminal_token}}; se commitea (npx = tooling dev, no dependencia Go).
DoD: openapi.yaml y postman/ generados y commiteados; headers de error
correctos (X-Request-Id presente); test smoke.

### T5 — Auth humanos
`internal/auth`: argon2id (params regla 4), JWT EdDSA access 15 min, claims
`sub`(user id), `typ:"user"`, `iss:"mkpos-server"`, `aud:"mkpos-api"`, header `kid`
(hash corto de la pública — rotación futura sin romper verificación). Leeway 60s.
- `POST /auth/login` {username, password} → 200 {access_token, user, permissions[]}
  + refresh: token 256-bit base64url; BD solo SHA-256; expira 30d. Entrega DUAL:
  Set-Cookie `mkpos_rt` (HttpOnly, Secure según config, SameSite=Lax,
  Path=/api/v1/auth) Y campo `refresh_token` en body (mobile lo usa; SPA lo ignora).
- `POST /auth/refresh`: toma refresh de cookie si existe, si no del body.
  Rotación: fila nueva + viejo revoked_at + replaced_by_id. **Reuso de token ya
  rotado = robo: revocar TODA la cadena del usuario + 401.**
- `POST /auth/logout`: revoca el presentado + limpia cookie.
- `GET /auth/me` → user + roles + permissions efectivos.
- Lockout login: contador en memoria por (username): 5 fallos → 429 con retry
  exponencial (30s, 60s, 120s… cap 15 min); reset al éxito. (Una instancia v1:
  memoria basta; documentado en código.)
- Middleware `RequireUser`; `RequirePermission(code)` consulta BD por request
  (join user_roles→role_permissions; scope: permiso global si user_roles.branch_id
  NULL, si no debe matchear el branch del recurso cuando la ruta lo tenga).
  Permisos NO viajan en el JWT (revocación inmediata > tamaño).
- Password policy: min 10 chars; PIN: 4-6 dígitos. Validación en users y resets (T7).
Tests: login ok/fail/lockout; refresh rota; reuso revoca cadena (verificar BD);
cookie y body ambos funcionan; permiso denegado 403; token expirado 401; aud/iss
mal 401.
DoD: suite T5 verde contra BD compose.

### T6 — Auth terminales (M2M)
- `POST /terminals` (terminals.manage) {branch_id, code, name} → PENDIENTE.
  Code único GLOBAL (formato sugerido S01-T01; validar `^[A-Z0-9-]{3,12}$`).
- `POST /terminals/{id}/enrollment-codes` (terminals.enroll): genera
  `XXXX-XXXX-XXXX` (A-Z2-9 sin ambiguos, crypto/rand), responde el claro UNA vez,
  BD solo SHA-256, expira 72h; invalida (invalidated_at) códigos previos no usados
  de esa terminal.
- `POST /enrollment` (público, rate-limit 5/min/IP) {code}: valida
  hash+vigencia+no usado+no invalidado+terminal PENDIENTE → genera client_id
  (`term_`+uuid) y client_secret 256-bit → guarda argon2id → marca used_at,
  terminal ACTIVO+enrolled_at → responde {client_id, client_secret, terminal,
  branch, warehouse_id default} UNA vez.
- `POST /auth/token` {grant_type:"client_credentials", client_id, client_secret}
  → JWT 15 min claims sub=terminal_id, `typ:"terminal"`, `branch_id`, scopes
  `sync:push sync:pull catalog:read`. Rechaza terminal ≠ ACTIVO o credencial
  revocada. Actualiza last_used_at + terminals.last_seen_at.
- `POST /terminals/{id}/revoke`: REVOCADO + revoked_at + revoca credenciales.
- Middleware `RequireTerminal` (typ=terminal + status ACTIVO en BD).
Tests: flujo completo enrolar→token→endpoint sync; código reusado/expirado/
invalidado falla; segundo código invalida primero; terminal revocada 401;
JWT user en ruta terminal 403 y viceversa.
DoD: suite verde.

### T7 — CRUD administración
Todos con RequireUser + permiso del mapa. Validación huma (formatos DNI 8, RUC 11,
email, PIN, precios ≥ 0). Unique violado → 409 con mensaje claro español.
Particularidades:
- `POST /branches`: body trae `warehouse_id` (existente) XOR `warehouse:{code,name}`
  inline (el switch "crear almacén para esta sucursal" del admin) — ambos o
  ninguno = 422. Inline: crea warehouse + branch en UNA tx. Respuesta embebe
  siempre `warehouse_id`. Permite: 1 almacén compartido por todas, varios
  repartidos, o uno por sucursal.
- `PATCH /branches/{id}` is_active:false NO desactiva warehouses (histórico
  intacto; puede estar compartido). `PATCH` puede reapuntar `warehouse_id`
  (config-rara; caveat offline documentado en INDEX).
- users: create exige ≥1 de password/pin según rol previsto; reset-password/
  reset-pin devuelven el temporal UNA vez (quien resetea lo dicta al empleado).
- roles: PATCH bloquea code/name de is_system (409); PUT permissions reemplaza set.
- products: `POST` auto-crea la presentación base (name = etiqueta de
  base_unit p.ej. "Unidad"/"Kilo", factor 1, is_sellable, default venta y
  compra; exige `sale_price_cents` del body → price_cents). Precios viven en
  presentaciones: PATCH de la presentación (catálogo es estado vigente, no
  ledger); updated_seq avanza solo (trigger) → POS lo verá en pull. Barcodes:
  alta/baja por endpoints anidados; baja = is_active:false (sync necesita la
  fila). Unicidad global del barcode violada → 409 diciendo QUÉ producto lo tiene.
- `GET /products/barcode-lookup?barcode=`: proxy server→Open Food Facts
  (`https://world.openfoodfacts.org/api/v2/product/{barcode}.json`, timeout 3s,
  User-Agent propio). Respuesta `{found, name?, brand?, quantity?, category_hint?}`;
  red caída o 404 → `{found:false}` (JAMÁS bloquea alta manual). Sin caché ni
  imágenes (PROYECTO § 11).
- settings: GET/PATCH business_settings (singleton). PATCH is_formalized:true
  exige ruc y legal_name presentes (422 si no) — la activación REAL del cálculo
  la hace el POS al ver el flag por pull. `icbper_cents` editable (≥ 0; tarifa
  legal sube cada año).
Tests por recurso: crear ok, validación 422, permiso 403, unique 409, paginación
cursor estable, soft-delete oculta de listados default (`?include_inactive=` para verlos).
DoD: suite verde; openapi regenerado commiteado.

### T8 — Compras y stock
Transiciones en `internal/domain` (tabla explícita estado×acción).
- `POST /purchases` {warehouse_id, kind, supplier_id?, doc_reference?,
  perception_cents?, items:[{product_presentation_id, quantity,
  unit_cost_cents}]}: server valida presentación is_purchasable y snapshotea
  presentation_name + factor. MAYORISTA → nace RECIBIDA + received_at +
  stock_movements COMPRA en unidad base (+qty × factor, purchase_item_id,
  occurred_at=received_at, user=created_by) MISMA tx. DISTRIBUIDORA → nace
  PEDIDA (ordered_at obligatorio), sin stock. Al RECIBIR: refresca
  products.cost_cents = half_up(unit_cost_cents ÷ factor) (costo referencial
  por unidad base, último gana).
- `POST /purchases/{id}/receive`: PEDIDA→RECIBIDA + movimientos (idem). Segunda
  vez → 409. `POST /purchases/{id}/cancel`: PEDIDA→CANCELADA; RECIBIDA no se
  cancela (409; corrección = AJUSTE).
- `total_cents` y `items[].total_cents` los calcula el server (redondeo canónico);
  si el cliente manda totales, se ignoran.
- `GET /stock`: stock_levels + products (name, unit, min_stock) + flag low
  (`quantity < min_stock AND min_stock > 0`); filtro branch (suma almacenes) o
  warehouse.
- `GET /products/{id}/kardex`: movimientos orden occurred_at DESC, con origen
  legible (tipo + referencia venta/compra + usuario), paginado.
- `POST /stock/adjustments` {warehouse_id, product_id, type AJUSTE|MERMA,
  quantity "±x.xxx", reason} (stock.adjust): inserta movimiento
  (occurred_at=now); signos: CHECK de BD manda (rechazo → 422 claro).
- Conteos físicos (inventariado; sirve también de carga inicial de inventario):
  `POST /inventory-counts` {warehouse_id, note?} → EN_CURSO (segundo abierto
  en el mismo almacén → 409, ux parcial lo garantiza). `PUT /{id}/items`
  upsert [{product_id, counted_qty}]; expected_qty = snapshot de stock_levels
  al momento del upsert. `POST /{id}/apply` → UNA tx: AJUSTE por cada
  diff ≠ 0 (quantity = counted − expected, referencia inventory_count_item_id)
  + status APLICADO + applied_by/at. `POST /{id}/cancel` → CANCELADO.
  APLICADO/CANCELADO son inmutables (todo mutador → 409).
Tests: mayorista atómico (falla item → nada queda); receive dos veces 409;
cancelar recibida 409; presentación no comprable 422; movimiento COMPRA =
qty × factor; cost_cents recalculado ÷ factor; merma sin reason 422; stock
refleja; kardex ordenado; conteo: apply genera AJUSTEs exactos, segundo
conteo abierto 409, apply dos veces 409.
DoD: suite verde.

### T9 — Ventas/caja lectura + reportes
Ventas NACEN en el POS (sync T10). Aquí solo lectura + agregados.
- `GET /sales` filtros branch/terminal/status/rango sold_on_local; `GET /sales/{id}`
  embebe items+payments+document(+customer).
- `GET /cash-sessions` + `/{id}` (movimientos + Σ ventas EFECTIVO + fórmula arqueo).
- `internal/domain`: fórmula arqueo ÚNICA:
  `expected = opening + Σ payments EFECTIVO de ventas COMPLETADAS de la sesión + Σ INGRESO − Σ RETIRO`.
- Reportes (reports.read; todos filtro branch opcional + rango obligatorio ≤ 366d):
  `sales-daily` (Σ y count por sold_on_local, excluye ANULADA),
  `top-products` (por Σ total y por Σ quantity, limit), `cash-differences`
  (sesiones con difference ≠ 0), `margin` (venta − costo referencial cost_cents;
  marcado "aproximado" en description del campo).
Tests domain arqueo: sin ventas / con anuladas excluidas / con retiros; reportes
cuadran a mano contra seeds dev.
DoD: suite verde.

### T10 — Sync push (idempotente) ★corazón
`POST /sync/push` (RequireTerminal) body `{events:[{event_id, event_type,
occurred_at, payload}]}` máx 100, orden del array respetado, secuencial.
Respuesta por evento `{event_id, status: applied|duplicate|error, message?}`.
Por evento UNA tx: `INSERT sync_ingest_log ON CONFLICT (event_id) DO NOTHING`
→ 0 filas = duplicate (ack sin re-aplicar). Aplica según contrato de INDEX.md
(tipos, validaciones — TODAS). Extras:
- Fechas: si |sold_at − now()| > 48h → aplicar + WARN slog (reloj de tienda).
- `error` de validación → NO se inserta en ingest_log (POS puede corregir y
  reintentar) SALVO error permanente evidente (FK inexistente, CHECK violado):
  responde error con message accionable; POS lo aparca (P5).
- `sale.voided` de venta inexistente → error "venta aún no llegó" (el POS
  reintenta después: orden FIFO del outbox lo evita normalmente).
- Actualiza terminals.last_seen_at al final del batch (una vez).
Tests: mismo evento 2× → duplicate sin doble stock; batch 10 con el #3 malo →
9 applied+1 error; venta de otra branch → error; totales mal → error;
icbper_cents ≠ Σ items → error; presentación que no pertenece al product →
error; movimiento VENTA = −(quantity × factor) en unidad base; void →
ANULADA + contra-movimientos; customer nuevo se crea, existente se reusa
(mismo doc 2 terminales); tax>0 o icbper>0 con is_formalized=false → error.
DoD: suite verde (la más completa del repo).

### T11 — Sync pull
`GET /sync/pull?cursor=N` (RequireTerminal) →
```
{ cursor: M,
  business_settings: {...} | null,          // si cambió (updated_seq > N)
  branches[], warehouses[],                  // solo la branch del JWT y SU almacén
                                             // (branches.warehouse_id)
  users[],                                   // id, full_name, username, pin_hash,
                                             // is_active, updated_seq — JAMÁS password_hash
  product_categories[], brands[], products[],
  product_presentations[], product_barcodes[],
  customers[],                               // filas updated_seq > N
  rbac: {roles[], permissions[], role_permissions[], user_roles[]},  // snapshot COMPLETO siempre
  has_more: bool }                           // límite 500 filas/tabla; POS re-pide
```
users filtrado: solo usuarios con algún rol en la branch del JWT o global.
Tests: producto editado aparece con cursor viejo y no con nuevo; barcode nuevo
y presentación con precio cambiado llegan; PIN cambiado llega; password_hash
ausente en JSON (test explícito); rbac completo siempre; has_more funciona
con 600 productos.
DoD: suite verde.

### T12 — Endurecimiento
Rate limit memoria por IP: /auth/login (10/min), /auth/token (20/min),
/enrollment (5/min) + por username en login (lockout T5). Security headers
(nosniff, no-store en auth). Límite body 1 MiB (push 5 MiB). Validar
Content-Type. `terminals.last_seen_at` ya cubierto. Revisión: grep secretos en
logs (test que loggea y asserta ausencia). pgx pool: max conns config (default 10),
health check period.
DoD: `task lint` limpio; tests de rate limit y headers.

### T13 — Logs de requests (esquema logs)
`internal/requestlog`: middleware que captura método, route (patrón), path,
status, duración, ip, subject (user|terminal del JWT) y satélites (query,
body solo en mutaciones, headers, user-agent, error, body de respuesta solo
con status ≥ 400) → canal buffered → writer batch (INSERT multirow cada ~1 s
o 100 filas). Canal lleno = descartar y contar (WARN slog): el request path
JAMÁS espera al log.
- Redacción ANTES de insertar: denylist headers (authorization, cookie,
  set-cookie, x-api-key…); bodies de `/auth/*` y `/enrollment` JAMÁS
  (regla 8); body > MKPOS_LOGS_MAX_BODY_KB (default 32) truncado + flag.
- Opt-in por ruta al registrarla; `/health` nunca; pulls de sync sin cambios
  no se loguean por default (config).
- Janitor diario (goroutine + ticker): `logs.ensure_partitions(1)` +
  `logs.drop_partitions_older_than(MKPOS_LOGS_RETENTION_MONTHS, default 3)`.
- Config: MKPOS_LOGS_ENABLED (default true), retención, max body.
- `X-Request-Id` de la respuesta = `logs.requests.id` = `trace_id` de los
  errores RFC 7807: correlación directa al depurar.
Tests: request logueado con sus satélites; login NO deja body y authorization
ausente de headers; canal lleno no bloquea el handler; janitor crea la
partición del mes siguiente; trace_id de un error == fila en logs.requests.
DoD: suite verde.

### T14 — Suite integración E2E-repo
`internal/api/e2e_test.go` (build tag `e2e`; `task test:e2e`): levanta server
contra BD compose con schema fresco, corre EL flujo completo real:
db:reset → seeds → login admin → crea branch+terminal → enrollment-code →
enrollment → token M2M → pull inicial (cursor 0) → push venta (payload contrato
INDEX) → GET /sales la muestra → push void → stock vuelve → abre/cierra caja
con arqueo → reportes cuadran. Asserts numéricos exactos céntimo a céntimo.
DoD: `task test && task test:e2e` verdes desde clon limpio.

### T15 — Cierre F1 backend
README server real (comandos, env vars, estructura, cómo correr tests).
openapi.yaml final regenerado + commiteado. `task generate` idempotente (diff
limpio si nada cambió). CI GitHub Actions `.github/workflows/ci.yml`: postgres
service 18, task db:reset + test + lint (REQUIERE GATE-H1; si repos no existen
aún, dejar el yml commiteado y anotarlo en el reporte).
Checklist PROYECTO.md § 9 completo. Reporte final: endpoints totales, cobertura
de dominios, deudas anotadas.
DoD global: `docker compose up -d && task setup && task db:reset && task
db:seed:dev && task test && task test:e2e && task lint` todo verde desde clon
limpio. openapi.yaml refleja TODOS los endpoints.

---

## Tareas diferidas (F2+; INDEX las ordena — ejecutar antes de la primera pantalla que las consuma)

### T16 — Notificaciones (campanita)
`internal/notify`: `Notify(userID, type, title, body?, data)` → fila en
notifications.notifications (fanout-on-write: una fila por destinatario).
Registro de tipos en código: REPORTE_LISTO, STOCK_BAJO… (valores español,
PROYECTO § 6). Sin push FCM (decisión F3) ni SSE (aditivo futuro): entrega =
polling del cliente (TanStack Query 30-60 s + focus).
Endpoints (RequireUser; cada quien SOLO las suyas — ajena = 404, no filtrar
existencia): `GET /notifications` (paginado, `?unread_only=`) ·
`GET /notifications/unread-count` · `POST /notifications/{id}/read`
(idempotente) · `POST /notifications/read-all`.
Tests: fanout a N destinatarios crea N filas; read idempotente; read-all;
unread-count cuadra; notificación ajena 404.
DoD: suite verde; openapi + postman regenerados.

### T17 — Reportes en segundo plano (esquema reports; depende de T16)
`internal/reports`: registro de kinds (código español — VENTAS_MENSUAL,
KARDEX_PRODUCTO… — con validador de params y generador) + pool de workers
(goroutines del binario, MKPOS_REPORTS_WORKERS default 2): toman la fila
PENDIENTE más antigua con `FOR UPDATE SKIP LOCKED` → EN_PROCESO → generan
archivo vía `internal/storage` (v1 disco: MKPOS_STORAGE_DIR) → COMPLETADO
(file_*) → `notify` REPORTE_LISTO al solicitante. Error transitorio:
attempts++ con reintento interno (máx 3, backoff) → FALLIDO con error
legible. Graceful shutdown drena el worker; al arrancar, EN_PROCESO
huérfanos → FALLIDO "interrumpido" (el usuario re-solicita; simple v1).
Janitor: borra archivos con expires_at vencido (la fila queda; download
vencido = 410).
Endpoints: `POST /reports` {kind, params} valida contra el registro ANTES de
encolar (inválido = 422 sin fila) → 202 + reporte · `GET /reports` (míos,
paginado) · `GET /reports/{id}` (poll de estado) · `GET /reports/{id}/download`
(solo COMPLETADO no vencido). Formato v1: CSV (encoding/csv); XLSX (excelize)
recién cuando una pantalla lo pida. Los reportes rápidos de T9 SIGUEN
síncronos: esto es para exports pesados.
Tests: flujo encolar→worker→archivo→notificación; 2 workers no toman la misma
fila (SKIP LOCKED); kind inválido 422 sin encolar; download ajeno 404;
vencido 410; fallo deja FALLIDO + error legible; arranque rescata huérfanos.
DoD: suite verde; openapi + postman regenerados.
