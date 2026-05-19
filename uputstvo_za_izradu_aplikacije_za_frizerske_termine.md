# Uputstvo za izradu aplikacije za rezervaciju termina kod frizera

## 1. Cilj aplikacije

Cilj je napraviti aplikaciju pomoću koje korisnici mogu pronaći frizerski salon, vidjeti slobodne termine i poslati zahtjev za rezervaciju. Frizer ili salon zatim prihvata ili odbija zahtjev. Kada salon prihvati zahtjev, korisnik dobija obavještenje da je termin potvrđen.

Aplikacija treba podržavati:

- registraciju i prijavu korisnika
- registraciju frizerskih salona
- prikaz salona u listi i na mapi
- slike salona
- profilne slike korisnika i frizera
- usluge salona, trajanje i cijene
- radno vrijeme salona
- slobodne termine
- slanje zahtjeva za rezervaciju
- prihvatanje ili odbijanje termina od strane frizera
- notifikacije za korisnika i frizera
- pravilo da korisnik ne može imati više aktivnih rezervacija
- upozorenje za korisnike koji su kasno otkazivali ili se nisu pojavili
- ocjenjivanje salona/frizera nakon završenog termina
- mogućnost da frizer označi korisnika kao `NoShow`, odnosno da se nije pojavio

Prva verzija treba biti MVP, što znači minimalna verzija koja radi osnovnu stvar: korisnik pronađe salon, izabere termin, pošalje zahtjev, frizer potvrdi ili odbije, korisnik dobije obavještenje.

---

## 2. Tipovi korisnika

Aplikacija ima tri tipa korisnika.

### 2.1 Customer

Obični korisnik koji rezerviše termin.

Korisnik može:

- napraviti nalog
- prijaviti se
- urediti profil
- dodati profilnu sliku
- pretraživati salone
- gledati salone na mapi
- gledati slike salona
- vidjeti usluge salona
- vidjeti slobodne termine
- poslati zahtjev za rezervaciju
- otkazati termin
- dobiti obavještenje kada salon prihvati ili odbije termin
- ocijeniti salon nakon završenog termina

### 2.2 Barber / Salon owner

Korisnik koji vodi salon ili radi kao frizer.

Frizer može:

- napraviti salon
- urediti podatke salona
- dodati adresu i lokaciju salona
- dodati slike salona
- dodati usluge, trajanje i cijene
- podesiti radno vrijeme
- podesiti kapacitet salona
- vidjeti zahtjeve za termine
- prihvatiti ili odbiti zahtjev
- vidjeti kalendar termina
- označiti termin kao završen
- označiti korisnika kao `NoShow`
- vidjeti upozorenje ako korisnik ima kasna otkazivanja ili nedolaske

### 2.3 Admin

Admin nije obavezan u prvoj verziji, ali ga treba planirati.

Admin može:

- pregledati korisnike
- pregledati salone
- blokirati lažne ili problematične naloge
- ukloniti neprimjerene slike
- pregledati prijave korisnika

---

## 3. Glavna pravila aplikacije

### 3.1 Korisnik može imati samo jednu aktivnu rezervaciju

Korisnik ne može rezervisati novi termin dok ima aktivnu rezervaciju.

Aktivni statusi su:

```text
Pending
Accepted
```

To znači:

- ako korisnik već ima rezervaciju koja čeka potvrdu, ne može napraviti novu
- ako korisnik već ima prihvaćenu rezervaciju, ne može napraviti novu
- korisnik može napraviti novu rezervaciju tek kada se prethodna završi, otkaže, odbije ili istekne

Neaktivni statusi su:

```text
Rejected
CancelledByUser
CancelledByBarber
CancelledLate
Completed
NoShow
Expired
```

### 3.2 Pending i Accepted zauzimaju mjesto u terminu

Kada korisnik pošalje zahtjev za termin, status rezervacije je `Pending`.

Iako termin još nije potvrđen, on privremeno zauzima kapacitet salona.

Razlog: ako salon ima kapacitet 2, ne želimo da 10 korisnika pošalje zahtjev za isti termin.

### 3.3 Kapacitet salona

U MVP verziji korisnik ne mora birati tačno kod kojeg frizera ide.

Salon ima polje:

```text
capacity
```

To znači koliko korisnika salon može primiti u istom terminu.

Primjer:

```text
Salon Elite
capacity = 3
```

To znači da u terminu 10:00 salon može imati najviše 3 aktivne rezervacije.

Aktivne rezervacije su:

```text
Pending
Accepted
```

Ako je već 3/3 popunjeno, termin se više ne prikazuje kao slobodan.

### 3.4 Kasno otkazivanje

Ako korisnik otkaže termin manje od 3 sata prije početka termina, rezervacija dobija status:

```text
CancelledLate
```

Ako korisnik otkaže ranije, status je:

```text
CancelledByUser
```

Pravilo:

```text
Ako je manje od 3 sata do termina:
    status = CancelledLate
Inače:
    status = CancelledByUser
```

### 3.5 NoShow

Ako korisnik ne dođe na termin, frizer može kliknuti:

```text
Korisnik nije došao
```

Tada status rezervacije postaje:

```text
NoShow
```

### 3.6 Upozorenje za frizera

Kada korisnik pošalje zahtjev za termin, frizer treba vidjeti poruku o pouzdanosti korisnika.

Primjeri:

```text
Nemanja želi termin u petak u 15:30.

Status korisnika: Novi korisnik.
```

```text
Nemanja želi termin u petak u 15:30.

Status korisnika: Pouzdan korisnik.
```

```text
Nemanja želi termin u petak u 15:30.

Upozorenje: korisnik je jednom otkazao prekasno.
```

```text
Nemanja želi termin u petak u 15:30.

Upozorenje: korisnik ima 2 kasna otkazivanja i 1 nedolazak.
```

Pouzdanost korisnika se ne mora čuvati ručno u posebnoj tabeli. Može se računati iz tabele `reservations`.

---

## 4. Tabovi aplikacije

Aplikacija treba imati različite tabove za korisnika i za frizera.

---

## 4.1 Tabovi za običnog korisnika

### 4.1.1 Saloni

Ovdje korisnik vidi listu salona.

Treba prikazati:

- naziv salona
- glavnu sliku salona
- ocjenu salona
- adresu
- udaljenost ako je dostupna lokacija korisnika
- prvi slobodan termin
- dugme `Pogledaj` ili `Rezerviši`

Filteri:

- grad
- udaljenost
- ocjena
- cijena
- usluga
- prvi slobodan termin

### 4.1.2 Mapa

Na mapi se prikazuju saloni.

Svaki salon treba imati marker.

Kada korisnik klikne na marker, prikazuje se kratka kartica:

```text
Salon Elite
Ocjena: 4.8
Prvi slobodan termin: danas 16:30
[Pogledaj salon]
```

Za mapu se mogu koristiti Google Maps ili OpenStreetMap.

### 4.1.3 Termini

Korisnik vidi svoje rezervacije.

Sekcije:

- aktivni termini
- termini koji čekaju potvrdu
- prošli termini
- otkazani termini

Primjeri statusa:

```text
Čeka potvrdu
Prihvaćen
Odbijen
Otkazan
Završen
Niste se pojavili
```

Korisnik može otkazati aktivni termin.

Ako otkazuje manje od 3 sata prije termina, sistem treba status postaviti na `CancelledLate`.

### 4.1.4 Profil

Korisnik može urediti:

- ime i prezime
- email
- broj telefona
- profilnu sliku
- lozinku
- favorite
- podešavanja
- odjavu

Obavještenja mogu biti kao zvonce gore desno, ne moraju biti poseban tab.

---

## 4.2 Tabovi za frizera / salon

### 4.2.1 Danas

Ovo je dashboard za frizera.

Prikazati:

- današnje termine
- broj novih zahtjeva
- sljedeći termin
- slobodne slotove za danas
- status kapaciteta

Primjer:

```text
Danas

09:00 - slobodno 3/3
09:30 - Nemanja Pejić - Pending
10:00 - 2/3 popunjeno
10:30 - slobodno 3/3
```

### 4.2.2 Zahtjevi

Ovdje frizer vidi sve `Pending` zahtjeve.

Kartica zahtjeva treba izgledati ovako:

```text
Nemanja Pejić želi termin u petak u 15:30.
Usluga: Muško šišanje
Trajanje: 30 min

Upozorenje: korisnik je jednom otkazao prekasno.

[Prihvati] [Odbij]
```

Ako je korisnik pouzdan:

```text
Status korisnika: Pouzdan korisnik.
```

Ako je novi:

```text
Status korisnika: Novi korisnik.
```

### 4.2.3 Kalendar

Frizer vidi termine po danu, sedmici ili mjesecu.

Za MVP je dovoljan dnevni prikaz.

Statusi termina:

```text
Slobodno
Pending
Accepted
Completed
NoShow
Cancelled
```

Ako salon ima kapacitet 3, termin treba prikazati kao:

```text
10:00 - 2/3 popunjeno
10:30 - 3/3 popunjeno
11:00 - 0/3 popunjeno
```

### 4.2.4 Salon

Ovdje frizer uređuje svoj salon.

Podsekcije:

- podaci salona
- slike
- usluge
- radno vrijeme
- pauze
- kapacitet
- lokacija

Podaci salona:

- naziv
- opis
- adresa
- grad
- država
- telefon
- lokacija na mapi
- kapacitet

Slike:

- dodavanje slika salona
- izbor glavne slike
- brisanje slika

Usluge:

- naziv usluge
- opis
- trajanje
- cijena
- aktivna/neaktivna

Radno vrijeme:

- ponedjeljak
- utorak
- srijeda
- četvrtak
- petak
- subota
- nedjelja

Pauze:

- npr. 12:00 - 13:00

Kapacitet:

- koliko korisnika salon može primiti u istom terminu

### 4.2.5 Profil

Frizer uređuje svoj korisnički profil:

- ime i prezime
- email
- telefon
- profilna slika
- lozinka
- odjava

---

## 5. Statusi rezervacije

Rezervacija mora imati status.

Koristiti sljedeće statuse:

```text
Pending
Accepted
Rejected
CancelledByUser
CancelledByBarber
CancelledLate
Completed
NoShow
Expired
```

Objašnjenje:

```text
Pending - korisnik je poslao zahtjev, frizer još nije odgovorio
Accepted - frizer je prihvatio termin
Rejected - frizer je odbio termin
CancelledByUser - korisnik je otkazao na vrijeme
CancelledByBarber - frizer je otkazao termin
CancelledLate - korisnik je otkazao prekasno
Completed - termin je završen
NoShow - korisnik se nije pojavio
Expired - frizer nije odgovorio na vrijeme
```

---

## 6. API rute

Backend treba imati REST API.

---

## 6.1 Auth

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/logout
GET  /api/auth/me
```

### Register request

```json
{
  "fullName": "Nemanja Pejić",
  "email": "nemanja@example.com",
  "password": "test1234",
  "role": "Customer"
}
```

### Login response

```json
{
  "token": "jwt-token",
  "user": {
    "id": "...",
    "fullName": "Nemanja Pejić",
    "role": "Customer"
  }
}
```

---

## 6.2 Users

```text
GET    /api/users/me
PUT    /api/users/me
POST   /api/users/me/profile-image
```

---

## 6.3 Salons

```text
GET    /api/salons
GET    /api/salons/{id}
POST   /api/salons
PUT    /api/salons/{id}
DELETE /api/salons/{id}
```

### GET /api/salons

Query parametri:

```text
city
serviceId
minRating
latitude
longitude
radiusKm
sortBy
```

### Salon response

```json
{
  "id": "...",
  "name": "Salon Elite",
  "description": "Moderan frizerski salon.",
  "address": "Ulica 1",
  "city": "Prijedor",
  "latitude": 44.9800,
  "longitude": 16.7000,
  "capacity": 3,
  "rating": 4.8,
  "mainImageUrl": "https://...",
  "firstAvailableSlot": "2026-05-22T15:30:00"
}
```

---

## 6.4 Salon images

```text
GET    /api/salons/{salonId}/images
POST   /api/salons/{salonId}/images
DELETE /api/salons/{salonId}/images/{imageId}
PUT    /api/salons/{salonId}/images/{imageId}/main
```

---

## 6.5 Services

```text
GET    /api/salons/{salonId}/services
POST   /api/salons/{salonId}/services
PUT    /api/services/{serviceId}
DELETE /api/services/{serviceId}
```

---

## 6.6 Working hours

```text
GET /api/salons/{salonId}/working-hours
PUT /api/salons/{salonId}/working-hours
```

---

## 6.7 Salon breaks

```text
GET    /api/salons/{salonId}/breaks
POST   /api/salons/{salonId}/breaks
PUT    /api/salons/{salonId}/breaks/{breakId}
DELETE /api/salons/{salonId}/breaks/{breakId}
```

---

## 6.8 Available slots

```text
GET /api/salons/{salonId}/available-slots?serviceId=...&date=2026-05-22
```

Response:

```json
{
  "date": "2026-05-22",
  "slots": [
    {
      "startTime": "2026-05-22T09:00:00",
      "endTime": "2026-05-22T09:30:00",
      "capacity": 3,
      "taken": 1,
      "available": 2
    },
    {
      "startTime": "2026-05-22T09:30:00",
      "endTime": "2026-05-22T10:00:00",
      "capacity": 3,
      "taken": 3,
      "available": 0
    }
  ]
}
```

Slotovi gdje je `available = 0` mogu se prikazati kao zauzeti ili se mogu sakriti.

---

## 6.9 Reservations

```text
POST /api/reservations
GET  /api/reservations/my
GET  /api/salons/{salonId}/reservations
POST /api/reservations/{id}/accept
POST /api/reservations/{id}/reject
POST /api/reservations/{id}/cancel
POST /api/reservations/{id}/complete
POST /api/reservations/{id}/no-show
```

### Create reservation request

```json
{
  "salonId": "...",
  "serviceId": "...",
  "startTime": "2026-05-22T15:30:00"
}
```

Backend sam računa `endTime` na osnovu trajanja usluge.

### Create reservation response

```json
{
  "id": "...",
  "status": "Pending",
  "message": "Zahtjev za termin je poslan salonu."
}
```

---

## 6.10 Notifications

```text
GET  /api/notifications
POST /api/notifications/{id}/read
POST /api/notifications/read-all
```

---

## 6.11 Reviews

```text
POST /api/reviews
GET  /api/salons/{salonId}/reviews
GET  /api/users/{userId}/reviews
```

Review se može napraviti samo ako je rezervacija `Completed`.

---

## 7. Logika kreiranja rezervacije

Kada korisnik klikne `Rezerviši`, backend mora uraditi sljedeće:

1. Provjeriti da je korisnik prijavljen.
2. Provjeriti da korisnik ima role `Customer`.
3. Provjeriti da korisnik nema aktivnu rezervaciju.
4. Provjeriti da salon postoji.
5. Provjeriti da je salon aktivan.
6. Provjeriti da usluga postoji.
7. Provjeriti da usluga pripada tom salonu.
8. Izračunati `end_time` na osnovu trajanja usluge.
9. Provjeriti da je salon otvoren u traženom periodu.
10. Provjeriti da termin ne upada u pauzu.
11. Provjeriti da termin ne prelazi kapacitet salona.
12. Kreirati rezervaciju sa statusom `Pending`.
13. Kreirati notifikaciju za vlasnika salona/frizera.

Pseudokod:

```text
CreateReservation(customerId, salonId, serviceId, startTime):

    activeReservationCount = count reservations
        where customer_id = customerId
        and status in ('Pending', 'Accepted')

    if activeReservationCount > 0:
        return error "Već imate aktivnu rezervaciju."

    service = get service
    salon = get salon

    endTime = startTime + service.duration_minutes

    if salon is not open between startTime and endTime:
        return error "Salon ne radi u tom terminu."

    if time overlaps salon break:
        return error "Termin je u pauzi salona."

    activeReservationsInSlot = count reservations
        where salon_id = salonId
        and status in ('Pending', 'Accepted')
        and start_time < endTime
        and end_time > startTime

    if activeReservationsInSlot >= salon.capacity:
        return error "Termin je zauzet."

    create reservation with status Pending

    create notification for salon owner

    return success
```

---

## 8. Logika prihvatanja rezervacije

Kada frizer klikne `Prihvati`:

1. Provjeriti da je frizer vlasnik salona.
2. Provjeriti da rezervacija postoji.
3. Provjeriti da je status `Pending`.
4. Ponovo provjeriti kapacitet termina.
5. Status postaviti na `Accepted`.
6. Popuniti `accepted_at`.
7. Kreirati notifikaciju za korisnika.

Notifikacija korisniku:

```text
Salon Elite je prihvatio vaš termin za petak u 15:30.
```

---

## 9. Logika odbijanja rezervacije

Kada frizer klikne `Odbij`:

1. Provjeriti da je frizer vlasnik salona.
2. Provjeriti da je rezervacija `Pending`.
3. Status postaviti na `Rejected`.
4. Popuniti `rejected_at`.
5. Kreirati notifikaciju za korisnika.

Notifikacija:

```text
Salon Elite je odbio vaš zahtjev za termin.
```

---

## 10. Logika otkazivanja rezervacije

Kada korisnik otkaže termin:

1. Provjeriti da je korisnik vlasnik rezervacije.
2. Provjeriti da je status `Pending` ili `Accepted`.
3. Izračunati koliko vremena ima do početka termina.
4. Ako ima manje od 3 sata, status je `CancelledLate`.
5. Ako ima 3 sata ili više, status je `CancelledByUser`.
6. Popuniti `cancelled_at`.
7. Kreirati notifikaciju za salon.

Pseudokod:

```text
CancelReservation(reservationId, customerId):

    reservation = get reservation

    if reservation.customer_id != customerId:
        return forbidden

    if reservation.status not in ('Pending', 'Accepted'):
        return error "Rezervacija se ne može otkazati."

    hoursUntilStart = reservation.start_time - now

    if hoursUntilStart < 3 hours:
        reservation.status = 'CancelledLate'
    else:
        reservation.status = 'CancelledByUser'

    reservation.cancelled_at = now

    create notification for salon owner
```

---

## 11. Logika NoShow

Kada korisnik ne dođe:

1. Frizer klikne `Korisnik nije došao`.
2. Backend provjeri da je frizer vlasnik salona.
3. Backend provjeri da je rezervacija `Accepted`.
4. Backend postavlja status na `NoShow`.
5. Kreira se zapis koji će kasnije uticati na upozorenje korisnika.

---

## 12. Logika Completed

Kada je termin završen:

1. Frizer klikne `Završeno`.
2. Status postaje `Completed`.
3. Popunjava se `completed_at`.
4. Korisniku se može poslati notifikacija da ocijeni salon.

Notifikacija:

```text
Kako biste ocijenili salon Elite?
```

---

## 13. Logika upozorenja za korisnika

Upozorenje se računa iz istorije rezervacija korisnika.

SQL za kasna otkazivanja:

```sql
SELECT COUNT(*)
FROM reservations
WHERE customer_id = @customerId
AND status = 'CancelledLate';
```

SQL za nedolaske:

```sql
SELECT COUNT(*)
FROM reservations
WHERE customer_id = @customerId
AND status = 'NoShow';
```

SQL za završene termine:

```sql
SELECT COUNT(*)
FROM reservations
WHERE customer_id = @customerId
AND status = 'Completed';
```

Pravila:

```text
Ako completedCount = 0 i lateCancelCount = 0 i noShowCount = 0:
    Status korisnika: Novi korisnik.

Ako completedCount > 0 i lateCancelCount = 0 i noShowCount = 0:
    Status korisnika: Pouzdan korisnik.

Ako lateCancelCount = 1 i noShowCount = 0:
    Upozorenje: korisnik je jednom otkazao prekasno.

Ako lateCancelCount > 1 i noShowCount = 0:
    Upozorenje: korisnik je X puta otkazao prekasno.

Ako noShowCount = 1 i lateCancelCount = 0:
    Upozorenje: korisnik se jednom nije pojavio na terminu.

Ako noShowCount > 1:
    Upozorenje: korisnik se X puta nije pojavio na terminu.

Ako lateCancelCount > 0 i noShowCount > 0:
    Upozorenje: korisnik ima X kasnih otkazivanja i Y nedolazaka.
```

---

## 14. Generisanje slobodnih termina

Ne praviti posebnu tabelu `time_slots` u MVP verziji.

Slobodni termini se generišu iz:

- radnog vremena salona
- pauza salona
- trajanja usluge
- postojećih rezervacija
- kapaciteta salona

Primjer:

Salon radi:

```text
09:00 - 17:00
```

Usluga traje:

```text
30 minuta
```

Kapacitet:

```text
3
```

Sistem generiše slotove:

```text
09:00 - 09:30
09:30 - 10:00
10:00 - 10:30
...
16:30 - 17:00
```

Za svaki slot se provjerava koliko ima aktivnih rezervacija.

Ako je:

```text
taken < capacity
```

slot je dostupan.

Ako je:

```text
taken >= capacity
```

slot je zauzet.

---

## 15. Tehnologije

Predložena arhitektura:

### Frontend

Opcija 1:

```text
React / Next.js
```

Opcija 2:

```text
Flutter
```

Za MVP je preporuka responsive web aplikacija, jer radi i na telefonu i na računaru.

### Backend

Pošto autor projekta zna C# i C++, dobra opcija je:

```text
ASP.NET Core Web API
```

### Baza

```text
PostgreSQL
```

### Autentifikacija

```text
JWT tokeni
```

### Slike

Slike ne čuvati direktno u bazi.

U bazi čuvati samo URL slike.

Slike se mogu čuvati u:

```text
Cloudinary
Amazon S3
Firebase Storage
lokalni storage za test verziju
```

### Mapa

Za mapu koristiti:

```text
Google Maps API
```

ili:

```text
OpenStreetMap + Leaflet
```

Za MVP može biti OpenStreetMap + Leaflet jer je jednostavnije i jeftinije.

---

## 16. Frontend ekrani

### 16.1 Login

Polja:

- email
- password

Dugmad:

- Login
- Register

### 16.2 Register

Polja:

- ime i prezime
- email
- telefon
- password
- tip korisnika: Customer ili Barber

Ako korisnik izabere Barber, nakon registracije treba ga poslati na ekran za kreiranje salona.

### 16.3 Customer - Saloni

Prikaz kartica salona.

Kartica:

```text
Slika salona
Naziv
Adresa
Ocjena
Prvi slobodan termin
Dugme Pogledaj
```

### 16.4 Customer - Detalji salona

Prikaz:

- slike salona
- naziv
- opis
- adresa
- mapa
- ocjena
- usluge
- slobodni termini
- dugme rezerviši

Tok rezervacije:

1. Korisnik izabere uslugu.
2. Korisnik izabere datum.
3. Sistem prikaže slobodne termine.
4. Korisnik izabere termin.
5. Korisnik klikne `Pošalji zahtjev`.
6. Sistem napravi `Pending` rezervaciju.

### 16.5 Customer - Termini

Prikaz:

- aktivni termini
- prošli termini
- otkazani termini

Za aktivni termin prikazati:

```text
Salon
Usluga
Datum
Vrijeme
Status
Dugme Otkaži
```

### 16.6 Customer - Profil

Polja:

- ime
- email
- telefon
- slika
- promjena lozinke
- odjava

---

## 16.7 Barber - Danas

Prikaz:

- današnji termini
- pending zahtjevi
- sljedeći termin
- status kapaciteta

### 16.8 Barber - Zahtjevi

Prikaz svih pending rezervacija.

Kartica:

```text
Ime korisnika
Datum i vrijeme
Usluga
Pouzdanost korisnika
Dugme Prihvati
Dugme Odbij
```

### 16.9 Barber - Kalendar

Dnevni prikaz termina.

Prikaz:

```text
09:00 - 1/3
09:30 - 3/3
10:00 - 0/3
```

Klik na termin prikazuje detalje rezervacija u tom slotu.

### 16.10 Barber - Salon

Podsekcije:

- osnovni podaci
- slike
- usluge
- radno vrijeme
- pauze
- kapacitet
- lokacija

### 16.11 Barber - Profil

Uređivanje profila vlasnika/frizera.

---

## 17. Notifikacije

U prvoj verziji notifikacije mogu biti samo unutar aplikacije.

Kasnije dodati:

- email
- push notification
- SMS

Primjeri notifikacija:

### Frizer dobija zahtjev

```text
Novi zahtjev za termin
Nemanja Pejić želi termin u petak u 15:30.
```

### Korisnik dobija potvrdu

```text
Termin prihvaćen
Salon Elite je prihvatio vaš termin za petak u 15:30.
```

### Korisnik dobija odbijanje

```text
Termin odbijen
Salon Elite je odbio vaš zahtjev za termin.
```

### Podsjetnik

```text
Podsjetnik
Imate termin za 2 sata u salonu Elite.
```

Podsjetnici nisu obavezni u prvoj verziji, ali su jako korisni kasnije.

---

## 18. Ocjene

Korisnik može ocijeniti salon samo ako ima `Completed` rezervaciju.

Pravilo:

```text
Review se može napraviti samo ako reservation.status = Completed.
```

Korisnik ne smije ocijeniti salon ako nije imao termin.

Frizer može ocijeniti korisnika kasnije, ali u MVP verziji je bolje koristiti pouzdanost kroz:

- kasna otkazivanja
- NoShow
- završene termine

---

## 19. Sigurnost

Potrebno:

- lozinke čuvati kao hash, nikako plain text
- koristiti JWT autentifikaciju
- provjeravati role korisnika
- korisnik smije vidjeti i mijenjati samo svoje podatke
- frizer smije mijenjati samo svoj salon
- frizer smije prihvatiti/odbiti samo rezervacije za svoj salon
- slike validirati po tipu i veličini
- ograničiti broj zahtjeva da se spriječi spam

---

## 20. Faze razvoja

### Faza 1 - Backend osnova

Napraviti:

- users
- auth
- salons
- services
- working hours
- reservations
- notifications

### Faza 2 - Customer frontend

Napraviti:

- login/register
- lista salona
- detalji salona
- izbor usluge
- izbor termina
- slanje zahtjeva
- moji termini
- profil

### Faza 3 - Barber frontend

Napraviti:

- kreiranje salona
- uređivanje salona
- usluge
- radno vrijeme
- zahtjevi
- prihvati/odbij
- kalendar

### Faza 4 - Slike i mapa

Dodati:

- upload slika
- glavna slika salona
- mapa salona
- lokacija salona

### Faza 5 - Ocjene i pouzdanost

Dodati:

- ocjena salona
- review komentari
- upozorenje za korisnika
- NoShow
- CancelledLate

### Faza 6 - Napredne funkcije

Kasnije dodati:

- pojedinačni frizeri unutar salona
- poseban kalendar za svakog frizera
- push notifikacije
- email podsjetnici
- SMS podsjetnici
- plaćanje unaprijed
- admin panel
- favoriti
- promocije

---

## 21. Šta ne raditi u prvoj verziji

Ne komplikovati prvu verziju sa:

- plaćanjem
- chatom
- AI preporukama
- komplikovanim admin panelom
- posebnim kalendarom za svakog frizera
- loyalty sistemom
- kuponima
- pretplatama

Prva verzija treba dokazati da osnovni proces radi:

```text
Korisnik pronađe salon → izabere termin → pošalje zahtjev → frizer prihvati → korisnik dobije obavještenje.
```

---

## 22. Najvažniji MVP cilj

Najvažniji cilj aplikacije je:

```text
Korisnik može za manje od 30 sekundi pronaći salon i poslati zahtjev za termin.
```

Drugi najvažniji cilj:

```text
Frizer može jednim klikom prihvatiti ili odbiti zahtjev.
```

Ako ova dva toka rade brzo i jednostavno, aplikacija ima smisla.

---

## 23. Kratki opis za developera

Treba napraviti web/mobile aplikaciju za rezervaciju termina kod frizera.

Postoje dvije glavne role: Customer i Barber.

Customer može pronaći salon, vidjeti slike, usluge i slobodne termine, poslati zahtjev za rezervaciju, otkazati termin i ocijeniti salon nakon završenog termina.

Barber može napraviti salon, dodati slike, usluge, radno vrijeme, kapacitet, prihvatiti ili odbiti zahtjeve, vidjeti kalendar i označiti korisnika kao `NoShow` ako se ne pojavi.

Korisnik ne može imati više od jedne aktivne rezervacije. Aktivne rezervacije su `Pending` i `Accepted`.

Salon u MVP verziji ima kapacitet. Ako je kapacitet 3, u istom terminu mogu biti najviše 3 aktivne rezervacije.

Ako korisnik otkaže manje od 3 sata prije termina, status postaje `CancelledLate`. Ako se ne pojavi, frizer može označiti `NoShow`. Kada korisnik pošalje novi zahtjev, frizer treba vidjeti upozorenje ako korisnik ima kasna otkazivanja ili nedolaske.

Prva verzija ne mora imati pojedinačne frizere u salonu. Dovoljno je da salon ima kapacitet. Kasnije se može dodati tabela `barbers` i `barber_id` u rezervacijama.

---

## 24. Zaključak

Aplikaciju treba napraviti jednostavno, ali sa dobrom bazom za širenje.

MVP treba sadržati:

- korisnike
- salone
- slike salona
- usluge
- radno vrijeme
- rezervacije
- kapacitet salona
- prihvatanje/odbijanje termina
- notifikacije
- kasno otkazivanje
- NoShow
- osnovne ocjene

Sve ostalo se može dodavati nakon što osnovni proces radi stabilno.

