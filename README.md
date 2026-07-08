# server — API central de Minimarket POS

API REST en Go (huma v2 + sqlc + pgx) sobre PostgreSQL 18. Fuente de verdad
consolidada del sistema: sync de terminales POS, autenticación (JWT humanos,
M2M terminales), RBAC y reportes.

> **Toda la documentación del proyecto vive en el repo
> [`mkpos-peru/docs`](https://github.com/mkpos-peru/docs)** (`docs/PROYECTO.md`).
> Este repo se trabaja clonado dentro de ese workspace — ver PROYECTO.md § 9.

## Estado

Fase 0 — esquema de BD completo y validado en `database/` (init.sql + seeds);
código Go pendiente. Plan de ejecución: `PLAN.md` (T1→T14); estructura objetivo
en PROYECTO.md § 2 (`cmd/api`, `internal/{config,api,auth,domain,store,sync}`,
`db/queries/`, `docker-compose.yml` solo-dev, `Taskfile.yml`, `openapi.yaml`
generado por huma).
