# server — API central de Minimarket POS

Parte servidor de **Minimarket POS**, un sistema para una cadena pequeña de
minimarkets en Piura (Perú). La regla número uno del sistema: **la caja de la
tienda nunca se detiene**, haya o no internet. Este servidor es donde todo
termina viviendo: las ventas que las cajas hicieron (incluso sin conexión),
el catálogo con sus precios, el inventario, los usuarios y los reportes.

Es una API REST en Go sobre PostgreSQL. La consumen tres clientes: el POS de
escritorio de cada tienda, el panel web de administración y la app móvil de
la dueña (repo `apps`).

> **Toda la documentación del proyecto vive en el repo
> [`mkpos-peru/docs`](https://github.com/mkpos-peru/docs)** (`docs/PROYECTO.md`
> es el documento maestro único). Este repo se trabaja clonado dentro de ese
> workspace — ver PROYECTO.md § 9.

## Qué hace (y qué no)

- **Recibe las ventas de las cajas** (sync push): ventas, pagos, movimientos
  de caja y stock, anulaciones. Es idempotente: la misma venta enviada dos
  veces se guarda una sola.
- **Reparte los datos maestros a las cajas** (sync pull): catálogo, precios,
  usuarios, configuración — de forma incremental.
- **Autentica a todos**: humanos con usuario/contraseña (panel y app móvil) y
  terminales POS con credenciales de máquina que nacen de un código de
  enrolamiento de un solo uso.
- **Sirve al panel y a la app**: catálogo, compras, inventario, arqueos de
  caja, reportes, notificaciones.
- **No procesa la venta en vivo.** La venta ocurre en el POS, offline, y llega
  aquí después. Si este servidor se cae, las tiendas siguen vendiendo.

## Cómo se ejecuta este repo

| Documento                                  | Para qué                                                                                                 |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| [`PLAN.md`](PLAN.md)                       | Plan de tareas T1→T17 para la IA ejecutora (qué hacer y cómo, en orden)                                  |
| [`database/README.md`](database/README.md) | Esquema de BD: 13 esquemas por dominio, orden de ejecución, convenciones                                 |
| `../docs/plans/INDEX.md`                   | Protocolo del agente, orden global entre repos e invariantes (redondeo, formatos JSON, contrato de sync) |

La estructura objetivo del código está en PROYECTO.md § 2. El contrato
`openapi.yaml` se genera desde el código y se commitea: de él nacen el
api-client TypeScript de `apps` y las colecciones Postman.

## Roadmap

Estado: **Fase 0 completa** — esquema de BD v3.1 en `database/` validado
contra PostgreSQL 18 real; código Go pendiente. Marcar cada tarea al
terminarla (protocolo INDEX, regla 5).

### F1 — Núcleo (T1→T15)

- [ ] T1 — Bootstrap (repo Go, Taskfile, docker-compose dev, config)
- [ ] T2 — sqlc (acceso a BD tipado, generado desde el DDL)
- [ ] T3 — Seeds dev (datos de prueba reproducibles)
- [ ] T4 — Núcleo HTTP (huma, errores RFC 7807, export de openapi.yaml)
- [ ] T5 — Auth humanos (login, refresh rotativo, logout, /auth/me)
- [ ] T6 — Auth terminales (M2M: enrolamiento + client_credentials)
- [ ] T7 — CRUD administración (catálogo, usuarios, sucursales, paginación)
- [ ] T8 — Compras y stock (kardex, ajustes, conteos físicos)
- [ ] T9 — Ventas/caja lectura + reportes
- [ ] T10 — Sync push (idempotente) ★corazón
- [ ] T11 — Sync pull (cursor incremental)
- [ ] T12 — Endurecimiento (rate limit, timeouts, headers)
- [ ] T13 — Logs de requests (esquema logs, telemetría)
- [ ] T14 — Suite integración E2E-repo
- [ ] T15 — Cierre F1 backend

### F2 — Antes del panel admin D8 (T16→T17)

- [ ] T16 — Notificaciones (campanita; la consumen admin D8 y mobile M6)
- [ ] T17 — Reportes en segundo plano (cola en BD, CSV descargable; lo consume admin D8)

El despliegue real (VPS, backups, rollout de la primera tienda) sigue
`../docs/plans/produccion.md` (PR1→PR8).
