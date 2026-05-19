#!/usr/bin/env python3
"""
Seed script - inserts 15 salons with owners, customers, services,
working hours, lunch breaks, and Unsplash images.

Run from the repo root:
    cd api && .\.venv\Scripts\Activate.ps1 && cd ..\database && python seed.py

Password for every seeded account: Lozinka123!
"""

import os
import sys
import psycopg2
import psycopg2.extras
from werkzeug.security import generate_password_hash
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'api', '.env'))
DATABASE_URL = os.getenv(
    'DATABASE_URL',
    'postgresql://makaze:makaze_password@localhost:5432/makaze_db',
)
PWD = generate_password_hash('Lozinka123!')

# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------

BARBERS = [
    ('mirko.jovanovic@makaze.ba',   'Mirko Jovanović',      '+38761100001'),
    ('dario.markovic@makaze.ba',    'Dario Marković',       '+38761100002'),
    ('stefan.nikolic@makaze.ba',    'Stefan Nikolić',       '+38761100003'),
    ('petar.simic@makaze.ba',       'Petar Simić',          '+38761100004'),
    ('luka.djuric@makaze.ba',       'Luka Đurić',           '+38761100005'),
    ('nikola.popovic@makaze.ba',    'Nikola Popović',       '+38761100006'),
    ('marko.stanic@makaze.ba',      'Marko Stanić',         '+38761100007'),
    ('bojan.lazic@makaze.ba',       'Bojan Lazić',          '+38761100008'),
    ('aleksandar.todorovic@makaze.ba', 'Aleksandar Todorović', '+38761100009'),
    ('ivan.pavlovic@makaze.ba',     'Ivan Pavlović',        '+38761100010'),
    ('filip.milovic@makaze.ba',     'Filip Milović',        '+38761100011'),
    ('ognjen.knezevic@makaze.ba',   'Ognjen Knežević',      '+38761100012'),
    ('dragan.kovac@makaze.ba',      'Dragan Kovač',         '+38761100013'),
    ('vladimir.saric@makaze.ba',    'Vladimir Šarić',       '+38761100014'),
    ('nemanja.petrovic@makaze.ba',  'Nemanja Petrović',     '+38761100015'),
]

CUSTOMERS = [
    ('ana.jankovic@gmail.com',          'Ana Janković',         '+38761200001'),
    ('milan.djordjevic@gmail.com',       'Milan Đorđević',       '+38761200002'),
    ('jelena.milosavljevic@gmail.com',   'Jelena Milosavljević', '+38761200003'),
    ('nikola.savic@gmail.com',           'Nikola Savić',         '+38761200004'),
    ('tamara.aleksic@gmail.com',         'Tamara Aleksić',       '+38761200005'),
    ('danilo.bogdanovic@gmail.com',      'Danilo Bogdanović',    '+38761200006'),
    ('milena.vuckovic@gmail.com',        'Milena Vučković',      '+38761200007'),
    ('srdjan.ilic@gmail.com',            'Srđan Ilić',           '+38761200008'),
    ('maja.mihailovic@gmail.com',        'Maja Mihailović',      '+38761200009'),
    ('dejan.zivkovic@gmail.com',         'Dejan Živković',       '+38761200010'),
    ('bojan.pejic@gmail.com',            'Bojan Pejić',          '+38761200011'),
]

# ---------------------------------------------------------------------------
# Salon data  (one entry per barber, same order as BARBERS list)
# ---------------------------------------------------------------------------
#   images: list of (url, is_main)
#   services: list of (name, duration_minutes, price)
#   hours: list of (day_of_week 1=Mon..7=Sun, open, close)  None = closed
#   breaks: list of (day_of_week, start, end, reason)
# ---------------------------------------------------------------------------

UNSPLASH = 'https://images.unsplash.com/photo-'
FMT      = '?auto=format&fit=crop&w=800&q=80'

def img(photo_id):
    return f'{UNSPLASH}{photo_id}{FMT}'

SALONS = [
    # 1 - Sarajevo
    {
        'name': 'Barbershop Mirko',
        'description': 'Klasičan muški frizerski salon u srcu Sarajeva. Specijalizovani za klasične šišanja i njegu brade.',
        'address': 'Ferhadija 12',
        'city': 'Sarajevo',
        'country': 'Bosna i Hercegovina',
        'lat': 43.8593, 'lng': 18.4324,
        'phone': '+38761100001',
        'capacity': 2,
        'images': [
            (img('1503951914875-452162b0f3f1'), True),
            (img('1621605815971-fbc98d665033'), False),
            (img('1560066984-138daaa70c8d'), False),
        ],
        'services': [
            ('Muško šišanje',       30, 15.00),
            ('Uređivanje brade',    20, 10.00),
            ('Šišanje + brada',     45, 22.00),
            ('Dječije šišanje',     20, 10.00),
        ],
        'hours': [
            (1,'08:00','19:00'), (2,'08:00','19:00'), (3,'08:00','19:00'),
            (4,'08:00','19:00'), (5,'08:00','19:00'), (6,'09:00','17:00'),
            (7, None, None),
        ],
        'breaks': [(1,'13:00','14:00','Pauza'), (2,'13:00','14:00','Pauza'),
                   (3,'13:00','14:00','Pauza'), (4,'13:00','14:00','Pauza'),
                   (5,'13:00','14:00','Pauza')],
    },
    # 2 - Sarajevo
    {
        'name': 'Hair Studio Elegance',
        'description': 'Moderni frizerski studio sa profesionalnim stilistima. Nudimo najnovije trendove u šišanju i bojenju.',
        'address': 'Titova 8',
        'city': 'Sarajevo',
        'country': 'Bosna i Hercegovina',
        'lat': 43.8571, 'lng': 18.4153,
        'phone': '+38761100002',
        'capacity': 3,
        'images': [
            (img('1522337360788-8b13dee7a37e'), True),
            (img('1585747860715-2ba37e788b70'), False),
            (img('1519345182560-3f2917c472ef'), False),
        ],
        'services': [
            ('Muško šišanje',           30, 18.00),
            ('Žensko šišanje',          45, 25.00),
            ('Bojenje kose',            90, 55.00),
            ('Pranje i feniranje',      30, 15.00),
            ('Uređivanje obrva',        15,  8.00),
        ],
        'hours': [
            (1,'09:00','20:00'), (2,'09:00','20:00'), (3,'09:00','20:00'),
            (4,'09:00','20:00'), (5,'09:00','20:00'), (6,'09:00','18:00'),
            (7,'10:00','15:00'),
        ],
        'breaks': [(1,'12:30','13:30','Ručak'), (2,'12:30','13:30','Ručak'),
                   (3,'12:30','13:30','Ručak'), (4,'12:30','13:30','Ručak'),
                   (5,'12:30','13:30','Ručak')],
    },
    # 3 - Sarajevo
    {
        'name': 'Old School Barber',
        'description': 'Vintage atmosfera, klasičan posao. Brijanje ravnom britvom, uređivanje brade i retro šišanja.',
        'address': 'Baščaršija 3',
        'city': 'Sarajevo',
        'country': 'Bosna i Hercegovina',
        'lat': 43.8608, 'lng': 18.4284,
        'phone': '+38761100003',
        'capacity': 1,
        'images': [
            (img('1599351431202-1e0f0137899a'), True),
            (img('1493256338651-d82f7acb2b38'), False),
        ],
        'services': [
            ('Klasično šišanje',        30, 15.00),
            ('Brijanje britvom',        30, 18.00),
            ('Šišanje + brijanje',      55, 30.00),
            ('Uređivanje brkova',       15,  8.00),
        ],
        'hours': [
            (1,'08:00','18:00'), (2,'08:00','18:00'), (3,'08:00','18:00'),
            (4,'08:00','18:00'), (5,'08:00','18:00'), (6,'09:00','15:00'),
            (7, None, None),
        ],
        'breaks': [(1,'13:00','14:00','Pauza'), (2,'13:00','14:00','Pauza'),
                   (3,'13:00','14:00','Pauza'), (4,'13:00','14:00','Pauza'),
                   (5,'13:00','14:00','Pauza')],
    },
    # 4 - Sarajevo
    {
        'name': 'Prestige Hair Salon',
        'description': 'Premium frizerski salon za muškarce i žene. Korištenje isključivo profesionalnih proizvoda.',
        'address': 'Zmaja od Bosne 45',
        'city': 'Sarajevo',
        'country': 'Bosna i Hercegovina',
        'lat': 43.8547, 'lng': 18.3976,
        'phone': '+38761100004',
        'capacity': 4,
        'images': [
            (img('1562322140-8baeececf3df'), True),
            (img('1605497788044-995a6a66a6e0'), False),
            (img('1512690459411-b9b26e67b9b5'), False),
        ],
        'services': [
            ('VIP muško šišanje',       45, 30.00),
            ('Žensko šišanje',          60, 40.00),
            ('Balayage',               120, 80.00),
            ('Keratin tretman',        120, 90.00),
            ('Uređivanje brade',        25, 15.00),
        ],
        'hours': [
            (1,'10:00','20:00'), (2,'10:00','20:00'), (3,'10:00','20:00'),
            (4,'10:00','20:00'), (5,'10:00','20:00'), (6,'10:00','18:00'),
            (7, None, None),
        ],
        'breaks': [],
    },
    # 5 - Sarajevo
    {
        'name': 'Fresh Cut Sarajevo',
        'description': 'Brz i kvalitetan servis za zaposlene muškarce. Bez čekanja, online booking.',
        'address': 'Skenderija 20',
        'city': 'Sarajevo',
        'country': 'Bosna i Hercegovina',
        'lat': 43.8558, 'lng': 18.4195,
        'phone': '+38761100005',
        'capacity': 2,
        'images': [
            (img('1553521041-1b69e8c3989c'), True),
            (img('1634302086687-e0e3deff5f7b'), False),
        ],
        'services': [
            ('Ekspresno šišanje',   20, 12.00),
            ('Šišanje + brada',     35, 20.00),
            ('Brada',               15,  8.00),
            ('Dječije šišanje',     20,  9.00),
        ],
        'hours': [
            (1,'07:00','20:00'), (2,'07:00','20:00'), (3,'07:00','20:00'),
            (4,'07:00','20:00'), (5,'07:00','20:00'), (6,'08:00','18:00'),
            (7,'09:00','14:00'),
        ],
        'breaks': [(1,'12:00','13:00','Ručak'), (2,'12:00','13:00','Ručak'),
                   (3,'12:00','13:00','Ručak'), (4,'12:00','13:00','Ručak'),
                   (5,'12:00','13:00','Ručak')],
    },
    # 6 - Banja Luka
    {
        'name': 'Royal Barbershop',
        'description': 'Ekskluzivan muški salon u Banjoj Luci. Posvećeni savršenom izgledu svakog klijenta.',
        'address': 'Veselina Masleše 15',
        'city': 'Banja Luka',
        'country': 'Bosna i Hercegovina',
        'lat': 44.7742, 'lng': 17.1912,
        'phone': '+38765100001',
        'capacity': 2,
        'images': [
            (img('1582095133179-bfd08cda8d18'), True),
            (img('1626808642875-0aa545482efb'), False),
            (img('1503951914875-452162b0f3f1'), False),
        ],
        'services': [
            ('Kraljevsko šišanje',  40, 25.00),
            ('Uređivanje brade',    25, 15.00),
            ('Šišanje + brada',     60, 35.00),
            ('Brijanje britvom',    30, 20.00),
        ],
        'hours': [
            (1,'09:00','19:00'), (2,'09:00','19:00'), (3,'09:00','19:00'),
            (4,'09:00','19:00'), (5,'09:00','19:00'), (6,'09:00','17:00'),
            (7, None, None),
        ],
        'breaks': [(1,'13:00','14:00','Pauza'), (2,'13:00','14:00','Pauza'),
                   (3,'13:00','14:00','Pauza'), (4,'13:00','14:00','Pauza'),
                   (5,'13:00','14:00','Pauza')],
    },
    # 7 - Banja Luka
    {
        'name': 'Marko Barber Studio',
        'description': 'Moderan studio za muško šišanje i njegu kose u centru Banje Luke.',
        'address': 'Kralja Petra I 33',
        'city': 'Banja Luka',
        'country': 'Bosna i Hercegovina',
        'lat': 44.7716, 'lng': 17.1887,
        'phone': '+38765100002',
        'capacity': 2,
        'images': [
            (img('1621605815971-fbc98d665033'), True),
            (img('1560066984-138daaa70c8d'), False),
        ],
        'services': [
            ('Muško šišanje',       30, 14.00),
            ('Fade šišanje',        35, 18.00),
            ('Brada',               20, 10.00),
            ('Šišanje + brada',     45, 25.00),
        ],
        'hours': [
            (1,'08:00','19:00'), (2,'08:00','19:00'), (3,'08:00','19:00'),
            (4,'08:00','19:00'), (5,'08:00','19:00'), (6,'09:00','16:00'),
            (7, None, None),
        ],
        'breaks': [(1,'12:30','13:30','Ručak'), (2,'12:30','13:30','Ručak'),
                   (3,'12:30','13:30','Ručak'), (4,'12:30','13:30','Ručak'),
                   (5,'12:30','13:30','Ručak')],
    },
    # 8 - Banja Luka
    {
        'name': 'Bojan\'s Cuts',
        'description': 'Prijatan i moderan frizerski salon. Specijalizovani za skin fade i teksturisane stilove.',
        'address': 'Bulevar vojvode Stepe 7',
        'city': 'Banja Luka',
        'country': 'Bosna i Hercegovina',
        'lat': 44.7689, 'lng': 17.1943,
        'phone': '+38765100003',
        'capacity': 1,
        'images': [
            (img('1522337360788-8b13dee7a37e'), True),
            (img('1585747860715-2ba37e788b70'), False),
        ],
        'services': [
            ('Skin fade',           35, 18.00),
            ('Muško šišanje',       30, 14.00),
            ('Textured crop',       30, 16.00),
            ('Brada + oblikovanje', 25, 12.00),
            ('Dječije šišanje',     20, 10.00),
        ],
        'hours': [
            (1,'09:00','18:00'), (2,'09:00','18:00'), (3,'09:00','18:00'),
            (4,'09:00','18:00'), (5,'09:00','18:00'), (6,'09:00','15:00'),
            (7, None, None),
        ],
        'breaks': [],
    },
    # 9 - Tuzla
    {
        'name': 'The Barber Tuzla',
        'description': 'Profesionalan muški salon u Tuzli. Sve usluge njege kose i brade na jednom mjestu.',
        'address': 'Turalibegova 12',
        'city': 'Tuzla',
        'country': 'Bosna i Hercegovina',
        'lat': 44.5384, 'lng': 18.6752,
        'phone': '+38761300001',
        'capacity': 2,
        'images': [
            (img('1519345182560-3f2917c472ef'), True),
            (img('1599351431202-1e0f0137899a'), False),
            (img('1493256338651-d82f7acb2b38'), False),
        ],
        'services': [
            ('Muško šišanje',       30, 13.00),
            ('Uređivanje brade',    20,  9.00),
            ('Šišanje + brada',     45, 20.00),
            ('Brijanje britvom',    30, 16.00),
        ],
        'hours': [
            (1,'08:00','18:00'), (2,'08:00','18:00'), (3,'08:00','18:00'),
            (4,'08:00','18:00'), (5,'08:00','18:00'), (6,'09:00','15:00'),
            (7, None, None),
        ],
        'breaks': [(1,'13:00','14:00','Pauza'), (2,'13:00','14:00','Pauza'),
                   (3,'13:00','14:00','Pauza'), (4,'13:00','14:00','Pauza'),
                   (5,'13:00','14:00','Pauza')],
    },
    # 10 - Tuzla
    {
        'name': 'Brothers Barbershop',
        'description': 'Porodičan salon braće Pavlović. Topla atmosfera i vrhunski rezultati od 2018. godine.',
        'address': 'Maršala Tita 44',
        'city': 'Tuzla',
        'country': 'Bosna i Hercegovina',
        'lat': 44.5401, 'lng': 18.6789,
        'phone': '+38761300002',
        'capacity': 3,
        'images': [
            (img('1562322140-8baeececf3df'), True),
            (img('1605497788044-995a6a66a6e0'), False),
        ],
        'services': [
            ('Klasično šišanje',    30, 13.00),
            ('Fade',                35, 16.00),
            ('Brada',               20,  9.00),
            ('Šišanje + brada',     50, 22.00),
            ('Dječije šišanje',     20,  9.00),
            ('Brijanje',            25, 14.00),
        ],
        'hours': [
            (1,'08:00','20:00'), (2,'08:00','20:00'), (3,'08:00','20:00'),
            (4,'08:00','20:00'), (5,'08:00','20:00'), (6,'08:00','17:00'),
            (7, None, None),
        ],
        'breaks': [(1,'12:00','13:00','Ručak'), (2,'12:00','13:00','Ručak'),
                   (3,'12:00','13:00','Ručak'), (4,'12:00','13:00','Ručak'),
                   (5,'12:00','13:00','Ručak')],
    },
    # 11 - Mostar
    {
        'name': 'Filip Barber Mostar',
        'description': 'Moderni muški frizerski salon u Mostaru. Pogled na Neretvu i savršen izgled.',
        'address': 'Kralja Tomislava 8',
        'city': 'Mostar',
        'country': 'Bosna i Hercegovina',
        'lat': 43.3437, 'lng': 17.8079,
        'phone': '+38763100001',
        'capacity': 2,
        'images': [
            (img('1512690459411-b9b26e67b9b5'), True),
            (img('1553521041-1b69e8c3989c'), False),
        ],
        'services': [
            ('Muško šišanje',       30, 14.00),
            ('Brada',               20, 10.00),
            ('Šišanje + brada',     45, 22.00),
            ('Dječije šišanje',     20, 10.00),
        ],
        'hours': [
            (1,'09:00','19:00'), (2,'09:00','19:00'), (3,'09:00','19:00'),
            (4,'09:00','19:00'), (5,'09:00','19:00'), (6,'09:00','16:00'),
            (7, None, None),
        ],
        'breaks': [(1,'13:00','14:00','Pauza'), (2,'13:00','14:00','Pauza'),
                   (3,'13:00','14:00','Pauza'), (4,'13:00','14:00','Pauza'),
                   (5,'13:00','14:00','Pauza')],
    },
    # 12 - Mostar
    {
        'name': 'Glamour Hair Studio',
        'description': 'Salon za muškarce i žene u Mostaru. Premium tretmani i savremeni stilovi.',
        'address': 'Rondo 22',
        'city': 'Mostar',
        'country': 'Bosna i Hercegovina',
        'lat': 43.3458, 'lng': 17.8121,
        'phone': '+38763100002',
        'capacity': 3,
        'images': [
            (img('1634302086687-e0e3deff5f7b'), True),
            (img('1582095133179-bfd08cda8d18'), False),
            (img('1626808642875-0aa545482efb'), False),
        ],
        'services': [
            ('Muško šišanje',       35, 15.00),
            ('Žensko šišanje',      50, 28.00),
            ('Bojenje kose',       100, 60.00),
            ('Pranje i fen',        30, 12.00),
            ('Uređivanje brade',    20, 10.00),
        ],
        'hours': [
            (1,'09:00','20:00'), (2,'09:00','20:00'), (3,'09:00','20:00'),
            (4,'09:00','20:00'), (5,'09:00','20:00'), (6,'09:00','18:00'),
            (7,'10:00','14:00'),
        ],
        'breaks': [],
    },
    # 13 - Zenica
    {
        'name': 'Pro Cut Zenica',
        'description': 'Profesionalan barbershop u centru Zenice. Iskusni majstori i brza usluga.',
        'address': 'Masarykova 5',
        'city': 'Zenica',
        'country': 'Bosna i Hercegovina',
        'lat': 44.2016, 'lng': 17.9073,
        'phone': '+38761400001',
        'capacity': 2,
        'images': [
            (img('1503951914875-452162b0f3f1'), True),
            (img('1621605815971-fbc98d665033'), False),
        ],
        'services': [
            ('Muško šišanje',       30, 13.00),
            ('Fade šišanje',        35, 16.00),
            ('Brada',               20,  9.00),
            ('Šišanje + brada',     45, 20.00),
        ],
        'hours': [
            (1,'08:00','18:00'), (2,'08:00','18:00'), (3,'08:00','18:00'),
            (4,'08:00','18:00'), (5,'08:00','18:00'), (6,'09:00','15:00'),
            (7, None, None),
        ],
        'breaks': [(1,'12:30','13:30','Pauza'), (2,'12:30','13:30','Pauza'),
                   (3,'12:30','13:30','Pauza'), (4,'12:30','13:30','Pauza'),
                   (5,'12:30','13:30','Pauza')],
    },
    # 14 - Zenica
    {
        'name': 'Elite Barber Zenica',
        'description': 'Elitni muški salon Zenica. Hot towel brijanje, premium tretmani, unikatno iskustvo.',
        'address': 'Kamberovića čikma 3',
        'city': 'Zenica',
        'country': 'Bosna i Hercegovina',
        'lat': 44.1998, 'lng': 17.9101,
        'phone': '+38761400002',
        'capacity': 1,
        'images': [
            (img('1560066984-138daaa70c8d'), True),
            (img('1522337360788-8b13dee7a37e'), False),
        ],
        'services': [
            ('Muško šišanje',           30, 15.00),
            ('Hot towel brijanje',      40, 22.00),
            ('Šišanje + hot towel',     65, 35.00),
            ('Uređivanje brade',        25, 13.00),
        ],
        'hours': [
            (1,'09:00','18:00'), (2,'09:00','18:00'), (3,'09:00','18:00'),
            (4,'09:00','18:00'), (5,'09:00','18:00'), (6, None, None),
            (7, None, None),
        ],
        'breaks': [(1,'13:00','14:00','Pauza'), (2,'13:00','14:00','Pauza'),
                   (3,'13:00','14:00','Pauza'), (4,'13:00','14:00','Pauza'),
                   (5,'13:00','14:00','Pauza')],
    },
    # 15 - Bihać
    {
        'name': 'Nemanja\'s Barbershop',
        'description': 'Jedini premium barbershop u Bihaću. Moderna oprema, vrhunska usluga.',
        'address': 'Bosanska 17',
        'city': 'Bihać',
        'country': 'Bosna i Hercegovina',
        'lat': 44.8175, 'lng': 15.8706,
        'phone': '+38761500001',
        'capacity': 2,
        'images': [
            (img('1585747860715-2ba37e788b70'), True),
            (img('1519345182560-3f2917c472ef'), False),
            (img('1599351431202-1e0f0137899a'), False),
        ],
        'services': [
            ('Muško šišanje',       30, 14.00),
            ('Brada',               20, 10.00),
            ('Šišanje + brada',     45, 22.00),
            ('Skin fade',           35, 18.00),
            ('Dječije šišanje',     20,  9.00),
        ],
        'hours': [
            (1,'08:00','19:00'), (2,'08:00','19:00'), (3,'08:00','19:00'),
            (4,'08:00','19:00'), (5,'08:00','19:00'), (6,'09:00','16:00'),
            (7, None, None),
        ],
        'breaks': [(1,'12:00','13:00','Pauza'), (2,'12:00','13:00','Pauza'),
                   (3,'12:00','13:00','Pauza'), (4,'12:00','13:00','Pauza'),
                   (5,'12:00','13:00','Pauza')],
    },
]


# ---------------------------------------------------------------------------
# Seed
# ---------------------------------------------------------------------------

def seed():
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    print('Connecting to:', DATABASE_URL.split('@')[-1])

    # -- barber users --------------------------------------------------------
    barber_ids = []
    for email, full_name, phone in BARBERS:
        cur.execute(
            """
            INSERT INTO users (full_name, email, phone_number, password_hash, role)
            VALUES (%s, %s, %s, %s, 'Barber')
            ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name
            RETURNING id
            """,
            (full_name, email, phone, PWD),
        )
        barber_ids.append(cur.fetchone()['id'])
    print(f'  {len(barber_ids)} barber users OK')

    # -- salons & related data -----------------------------------------------
    for i, (salon_data, owner_id) in enumerate(zip(SALONS, barber_ids)):
        cur.execute(
            """
            INSERT INTO salons
                (owner_user_id, name, description, address, city, country,
                 latitude, longitude, phone_number, capacity)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT DO NOTHING
            RETURNING id
            """,
            (
                owner_id,
                salon_data['name'],
                salon_data['description'],
                salon_data['address'],
                salon_data['city'],
                salon_data['country'],
                salon_data['lat'],
                salon_data['lng'],
                salon_data['phone'],
                salon_data['capacity'],
            ),
        )
        row = cur.fetchone()
        if row is None:
            # Already exists – look it up
            cur.execute('SELECT id FROM salons WHERE owner_user_id = %s', (owner_id,))
            row = cur.fetchone()
        salon_id = row['id']

        # images
        for sort, (url, is_main) in enumerate(salon_data['images']):
            cur.execute(
                """
                INSERT INTO salon_images (salon_id, image_url, is_main, sort_order)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT DO NOTHING
                """,
                (salon_id, url, is_main, sort),
            )

        # services
        for svc_name, duration, price in salon_data['services']:
            cur.execute(
                """
                INSERT INTO services (salon_id, name, duration_minutes, price)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT DO NOTHING
                """,
                (salon_id, svc_name, duration, price),
            )

        # working hours
        for day, open_t, close_t in salon_data['hours']:
            if open_t is None:
                cur.execute(
                    """
                    INSERT INTO working_hours (salon_id, day_of_week, is_closed)
                    VALUES (%s, %s, TRUE)
                    ON CONFLICT (salon_id, day_of_week) DO NOTHING
                    """,
                    (salon_id, day),
                )
            else:
                cur.execute(
                    """
                    INSERT INTO working_hours
                        (salon_id, day_of_week, start_time, end_time, is_closed)
                    VALUES (%s, %s, %s, %s, FALSE)
                    ON CONFLICT (salon_id, day_of_week) DO NOTHING
                    """,
                    (salon_id, day, open_t, close_t),
                )

        # breaks
        for day, start, end, reason in salon_data['breaks']:
            cur.execute(
                """
                INSERT INTO salon_breaks (salon_id, day_of_week, start_time, end_time, reason)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
                """,
                (salon_id, day, start, end, reason),
            )

        print(f'  Salon {i+1:2d}: {salon_data["name"]} ({salon_data["city"]}) OK')

    # -- customer users -------------------------------------------------------
    customer_ids = []
    for email, full_name, phone in CUSTOMERS:
        cur.execute(
            """
            INSERT INTO users (full_name, email, phone_number, password_hash, role)
            VALUES (%s, %s, %s, %s, 'Customer')
            ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name
            RETURNING id
            """,
            (full_name, email, phone, PWD),
        )
        customer_ids.append(cur.fetchone()['id'])
    print(f'  {len(customer_ids)} customer users OK')

    conn.commit()
    cur.close()
    conn.close()

    print()
    print('Seed finished!')
    print()
    print('Login credentials (password: Lozinka123!)')
    print('  Customers:')
    for email, name, _ in CUSTOMERS:
        print(f'    {email}')
    print('  Barbers (salon owners):')
    for email, name, _ in BARBERS:
        print(f'    {email}')


if __name__ == '__main__':
    try:
        seed()
    except Exception as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        sys.exit(1)
