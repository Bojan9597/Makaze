# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Makaze** ("scissors" in Serbian) is a barber shop appointment booking platform — a two-sided marketplace where customers find and book haircut appointments and barbers manage their salons and schedules.

## Architecture

Three-tier architecture:

```
Flutter App (mobile/web)  →  Flask REST API (port 5001)  →  PostgreSQL 16 (port 5433)
```

- **[api/app.py](api/app.py)** — monolithic Flask backend (~1,760 lines): auth, salons, services, reservations, notifications, reviews, image uploads
- **[app/lib/main.dart](app/lib/main.dart)** — monolithic Flutter frontend (~201KB): all UI and business logic in a single file
- **[database/schema.sql](database/schema.sql)** — full PostgreSQL schema: 11 tables, enums, triggers, indexes

### Key Domain Concepts

- **Roles:** `Customer`, `Barber`, `Admin` (stored in JWT, enforced per endpoint)
- **Reservation status flow:** `Pending → Accepted/Rejected → Completed/NoShow` (also `CancelledByUser`, `CancelledByBarber`, `CancelledLate`, `Expired`)
- **One-active-reservation rule:** A customer cannot book while they have a pending or accepted reservation
- **Available slots:** Dynamically computed from working hours, breaks, salon capacity, and existing reservations (`GET /api/salons/<id>/available-slots`)
- **Late cancellation:** Cancelling within 3 hours of appointment sets status `CancelledLate`; affects customer reliability score visible to barbers

### Database Tables

`users`, `salons`, `salon_images`, `barbers`, `services`, `working_hours`, `salon_breaks`, `reservations`, `notifications`, `reviews`, `favorite_salons`

## Running the Project

### Database (required first)
```powershell
# From repo root — starts PostgreSQL on port 5433 and Adminer UI on port 8080
docker compose up -d
```
Adminer: http://localhost:8080 | host: `db` | user/pass: `makaze`/`makaze_password` | db: `makaze_db`

### API (Flask)
```powershell
cd api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env   # then edit JWT_SECRET
python app.py            # http://127.0.0.1:5001
```
Health checks: `GET /health` and `GET /health/db`

### Flutter App
```powershell
cd app
flutter pub get
flutter run              # default device
flutter run -d web       # browser
flutter run -d chrome    # Chrome specifically
```

### Full stack via Docker
```powershell
docker compose up --build   # starts db + api; Flutter runs separately
```

## Environment Variables

Copy `api/.env.example` to `api/.env`. Key variables:

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Secret for signing JWT tokens (change before production) |
| `FLASK_PORT` | API port (default `5000` in .env, but `app.py` defaults to `5001`) |
| `UPLOAD_FOLDER` | Path for uploaded images |

## API Structure

All endpoints are prefixed `/api/`. Auth uses Bearer JWT tokens.

Key endpoint groups: `/auth`, `/users/me`, `/salons`, `/salons/<id>/images`, `/salons/<id>/services`, `/salons/<id>/working-hours`, `/salons/<id>/breaks`, `/salons/<id>/available-slots`, `/reservations`, `/notifications`, `/reviews`, `/favorites`

Full specification (in Serbian) is in [uputstvo_za_izradu_aplikacije_za_frizerske_termine.md](uputstvo_za_izradu_aplikacije_za_frizerske_termine.md).

## Flutter Dependencies

- `flutter_map` + `latlong2` — map display for salon discovery
- `http` — REST API calls
- `file_picker` — image upload from device
