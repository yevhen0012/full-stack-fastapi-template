# Fullstack Dev Test Task

This repository contains two deliverables:

- A role-aware access control implementation on top of the FastAPI full-stack template.
- A tunnel-only Ghost deployment script for Hetzner Cloud in `infra/ghost/`.

The application keeps the original FastAPI / SQLModel / PostgreSQL backend and React / TypeScript frontend, but adds explicit roles, backend authorization dependencies, role-aware frontend navigation, a metrics page, seed data, tests, and documentation.

## Implemented RBAC Scope

Roles:

- `admin`: full access to user management, role changes, and metrics.
- `manager`: can list users and view metrics, but cannot create, edit, or delete users.
- `member`: can access their own profile and normal app features only.

Permission matrix:

| Action | admin | manager | member |
| --- | --- | --- | --- |
| List all users | Yes | Yes | No |
| Create user | Yes | No | No |
| View metrics | Yes | Yes | No |
| View/update own profile | Yes | Yes | Yes |
| View another profile | Yes | Yes | No |
| Update any profile | Yes | No | No |
| Delete users | Yes | No | No |

Protected surfaces:

- `GET /api/v1/users/` is available to admins and managers.
- `POST /api/v1/users/`, `PATCH /api/v1/users/{user_id}`, and `DELETE /api/v1/users/{user_id}` are admin-only.
- `GET /api/v1/metrics/` is available to admins and managers.
- `/admin` is visible to admins and managers; write actions are hidden for managers.
- `/metrics` is visible to admins and managers.
- Unauthorized direct navigation shows an access denied page instead of silently redirecting.

## Authorization Approach

Roles are stored on `User.role` as one of `admin`, `manager`, or `member`. The existing `is_superuser` field is preserved for compatibility with the base template, but admin users are normalized so `role="admin"` and `is_superuser=true` stay aligned. A database migration adds the `role` column and backfills existing superusers to `admin`.

Backend authorization lives in FastAPI dependencies in `backend/app/api/deps.py`. The central helper is `require_roles(...)`, which keeps route-level permission checks declarative and easy to extend. User management routes use that dependency instead of scattering role checks through every handler. The only object-specific exception is profile access, where users can still read themselves and admins/managers can read other profiles.

The frontend learns capabilities from `UsersService.readUserMe()`, which now includes `role`. Shared permission helpers in `frontend/src/permissions.ts` drive sidebar visibility, page access, and whether user-management actions render. These frontend checks are UX-only; the backend remains the source of truth for enforcement.

## Run Locally

Prerequisites:

- Docker Desktop with Docker Compose.

Start the full stack from the repository root:

```bash
docker compose watch
```

Open:

- Frontend: `http://localhost:5173`
- Backend API docs: `http://localhost:8000/docs`
- Adminer: `http://localhost:8080`

If you prefer running only the frontend locally, install Bun and run:

```bash
cd frontend
bun install
bun run dev
```

The frontend still expects the backend to be running at `http://localhost:8000`.

## Seeded Test Users

The application seeds one admin from `.env` plus one manager and one member during backend startup.

| Role | Email | Password |
| --- | --- | --- |
| admin | `admin@example.com` | `changethis` |
| manager | `manager@example.com` | `changethis` |
| member | `member@example.com` | `changethis` |

The admin credentials come from:

```env
FIRST_SUPERUSER=admin@example.com
FIRST_SUPERUSER_PASSWORD=changethis
```

## Tests

Run the backend test suite in Docker:

```bash
docker compose up -d --wait backend
docker compose exec backend bash scripts/tests-start.sh
```

Run the focused RBAC tests:

```bash
docker compose exec backend bash scripts/tests-start.sh tests/api/routes/test_users.py tests/api/routes/test_metrics.py
```

Run frontend checks:

```bash
cd frontend
bun install
bun run build
bun run lint
```

Run Playwright tests:

```bash
docker compose up -d --wait backend
cd frontend
bunx playwright test
```

## Database Migration

RBAC adds a `role` column to the `user` table.

Migration file:

```text
backend/app/alembic/versions/b3a8e8a9d5f2_add_user_role.py
```

Docker startup runs the existing prestart flow, which applies Alembic migrations automatically. To run migrations manually inside the backend container:

```bash
docker compose exec backend alembic upgrade head
```

## Developer Notes

Important implementation files:

- `backend/app/models.py`: `UserRole` enum and `User.role`.
- `backend/app/api/deps.py`: reusable role authorization dependency.
- `backend/app/api/routes/users.py`: protected user-management routes.
- `backend/app/api/routes/metrics.py`: metrics endpoint for admins/managers.
- `backend/app/core/db.py`: seed admin, manager, and member users.
- `frontend/src/permissions.ts`: frontend capability helpers.
- `frontend/src/routes/_layout/admin.tsx`: role-aware user page.
- `frontend/src/routes/_layout/metrics.tsx`: metrics page.
- `frontend/src/components/Common/Forbidden.tsx`: friendly forbidden state.

The frontend client files under `frontend/src/client/` were updated to include the new `role` field and metrics service.

## Infrastructure Task: Ghost on Hetzner

The infrastructure deliverable is available in both `GHOST.md` and `infra/ghost/`. It provides a one-click script to deploy Ghost to a Hetzner Cloud VPS without public SSH access. The server is provisioned with cloud-init, runs Ghost and MySQL with Docker Compose, and exposes Ghost only through an outbound Cloudflare Tunnel.

See `GHOST.md` for the architecture, prerequisites, deployment command, security model, and cleanup steps.

## Scope Notes

The RBAC implementation is intentionally small and explicit. It favors readable dependencies and shared permission helpers over a larger policy framework. Observability for denied attempts and a formal ADR were left out to keep the implementation focused on the required authorization behavior, tests, setup, and documentation.
