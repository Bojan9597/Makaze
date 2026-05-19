# Makaze Flask API

API za logovanje i registraciju koristi PostgreSQL bazu iz `database/schema.sql`.

## Instalacija

Iz root foldera projekta:

```powershell
cd C:\Users\bojan\Desktop\Makaze\api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

U `.env` podesi `DATABASE_URL` ako se razlikuje od default konekcije.

## Pokretanje

Prvo baza mora raditi i schema mora biti ucitana.

Zatim:

```powershell
python app.py
```

API radi na:

```text
http://127.0.0.1:5001
```

Provjera:

```powershell
Invoke-WebRequest http://127.0.0.1:5001/health
Invoke-WebRequest http://127.0.0.1:5001/health/db
```

## Endpointi

### Registracija korisnika

```http
POST /api/auth/register
Content-Type: application/json
```

```json
{
  "role": "Customer",
  "fullName": "Nemanja Pejic",
  "email": "nemanja@example.com",
  "phoneNumber": "+387 61 222 333",
  "password": "password"
}
```

### Registracija salona

```json
{
  "role": "Salon",
  "fullName": "Marko Ilic",
  "email": "marko@salonelite.com",
  "phoneNumber": "+387 65 444 555",
  "password": "password",
  "salonName": "Salon Elite",
  "salonAddress": "Kralja Petra 12",
  "city": "Bijeljina"
}
```

### Login

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{
  "email": "nemanja@example.com",
  "password": "password"
}
```
