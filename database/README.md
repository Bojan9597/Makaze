# Makaze PostgreSQL baza

## Pokretanje preko Docker-a

Iz root foldera projekta pokreni:

```powershell
docker compose up -d
```

Baza ce se automatski napraviti iz fajla `database/schema.sql`.

Podaci za konekciju:

```text
Database: makaze_db
User: makaze
Password: makaze_password
Host sa racunara: localhost
Port: 5433
```

## Kako da vidis bazu u browseru

Nakon `docker compose up -d`, otvori:

```text
http://localhost:8080
```

U Adminer login formi unesi:

```text
System: PostgreSQL
Server: db
Username: makaze
Password: makaze_password
Database: makaze_db
```

Poslije logina vidjeces tabele: `users`, `salons`, `salon_images`, `barbers`, `services`, `working_hours`, `salon_breaks`, `reservations`, `notifications`, `reviews`.

## Kako da vidis bazu kroz terminal

Ako imas instaliran `psql`, koristi:

```powershell
psql -h localhost -p 5433 -U makaze -d makaze_db
```

Korisne komande u `psql`:

```sql
\dt
\d reservations
SELECT * FROM customer_reliability;
```

## Reset baze

Ako zelis obrisati bazu i napraviti je ponovo od nule:

```powershell
docker compose down -v
docker compose up -d
```

## Ako vec imas lokalni PostgreSQL bez Docker-a

Ako imas instaliran PostgreSQL lokalno, prvo napravi usera i bazu. Komanda ce traziti lozinku za `postgres` admin korisnika:

```powershell
.\database\setup_local_postgres.ps1
```

Ako zelis rucno, iste komande su:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U postgres -d postgres -f database/setup_local_postgres.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U makaze -d makaze_db -f database/schema.sql
```
