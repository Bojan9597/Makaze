import os
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from functools import wraps
from uuid import uuid4

import jwt
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
from flask import Flask, g, jsonify, request, send_from_directory
from flask_cors import CORS
from psycopg2 import errors
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://makaze:makaze_password@localhost:5432/makaze_db",
)
JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
JWT_ALGORITHM = "HS256"
TOKEN_DAYS = 7
ACTIVE_STATUSES = ("Pending", "Accepted")
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
ALLOWED_IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "webp", "gif"}


def create_app():
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 8 * 1024 * 1024
    CORS(app)
    ensure_upload_dirs()

    @app.teardown_appcontext
    def close_db(_error=None):
        connection = g.pop("db_connection", None)
        if connection is not None:
            connection.close()

    @app.errorhandler(psycopg2.OperationalError)
    def handle_db_connection_error(_error):
        return jsonify(
            {
                "message": (
                    "Baza nije dostupna ili su kredencijali pogresni. "
                    "Provjeri DATABASE_URL u api/.env."
                )
            }
        ), 503

    @app.errorhandler(psycopg2.DatabaseError)
    def handle_db_error(_error):
        get_db_connection().rollback()
        return jsonify({"message": "Greska u bazi podataka."}), 500

    @app.get("/health")
    def health():
        return jsonify({"status": "ok", "service": "makaze-api"})

    @app.get("/health/db")
    def db_health():
        with get_db_cursor() as cursor:
            cursor.execute("SELECT 1 AS ok")
            row = cursor.fetchone()
        return jsonify({"status": "ok", "database": row["ok"] == 1})

    @app.get("/uploads/<path:filename>")
    def uploaded_file(filename):
        return send_from_directory(UPLOAD_DIR, filename)

    @app.post("/api/auth/register")
    def register():
        data = request.get_json(silent=True) or {}

        role = normalize_role(data.get("role"))
        full_name = clean_text(data.get("fullName") or data.get("full_name"))
        email = clean_text(data.get("email")).lower()
        phone_number = clean_text(data.get("phoneNumber") or data.get("phone_number"))
        password = data.get("password") or ""
        salon_name = clean_text(data.get("salonName") or data.get("salon_name"))
        salon_address = clean_text(data.get("salonAddress") or data.get("salon_address"))
        city = clean_text(data.get("city"))
        country = clean_text(data.get("country")) or "BiH"
        latitude = numeric_or_none(data.get("latitude"))
        longitude = numeric_or_none(data.get("longitude"))

        errors_payload = validate_register_payload(
            role=role,
            full_name=full_name,
            email=email,
            password=password,
            salon_name=salon_name,
            salon_address=salon_address,
        )
        if errors_payload:
            return jsonify({"message": "Provjeri unesene podatke.", "errors": errors_payload}), 400

        connection = get_db_connection()
        try:
            with connection:
                with connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                    cursor.execute(
                        """
                        INSERT INTO users (full_name, email, phone_number, password_hash, role)
                        VALUES (%s, %s, %s, %s, %s)
                        RETURNING id, full_name, email, phone_number, profile_image_url, role
                        """,
                        (
                            full_name,
                            email,
                            phone_number or None,
                            generate_password_hash(password),
                            role,
                        ),
                    )
                    user = cursor.fetchone()

                    salon = None
                    if role == "Barber":
                        cursor.execute(
                            """
                            INSERT INTO salons (
                                owner_user_id, name, address, city, country,
                                latitude, longitude, capacity
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, %s, 1)
                            RETURNING *
                            """,
                            (
                                user["id"],
                                salon_name,
                                salon_address,
                                city or None,
                                country,
                                latitude,
                                longitude,
                            ),
                        )
                        salon = cursor.fetchone()
                        create_default_working_hours(cursor, salon["id"])
        except errors.UniqueViolation:
            connection.rollback()
            return jsonify({"message": "Korisnik sa ovim emailom vec postoji."}), 409

        token = create_token(user["id"], user["role"])
        return jsonify(
            {
                "token": token,
                "user": serialize_user(user),
                "salon": serialize_salon(salon),
            }
        ), 201

    @app.post("/api/auth/login")
    def login():
        data = request.get_json(silent=True) or {}
        email = clean_text(data.get("email")).lower()
        password = data.get("password") or ""

        if not email or not password:
            return jsonify({"message": "Email i lozinka su obavezni."}), 400

        with get_db_cursor() as cursor:
            cursor.execute(
                """
                SELECT id, full_name, email, phone_number, password_hash, profile_image_url, role
                FROM users
                WHERE email = %s
                """,
                (email,),
            )
            user = cursor.fetchone()

            if user is None or not check_password_hash(user["password_hash"], password):
                return jsonify({"message": "Pogresan email ili lozinka."}), 401

            salon = fetch_owner_salon(cursor, user["id"]) if user["role"] == "Barber" else None

        token = create_token(user["id"], user["role"])
        return jsonify(
            {
                "token": token,
                "user": serialize_user(user),
                "salon": serialize_salon(salon),
            }
        )

    @app.post("/api/auth/logout")
    @require_auth
    def logout():
        return jsonify({"message": "Odjavljeni ste."})

    @app.get("/api/auth/me")
    @require_auth
    def auth_me():
        user, salon = get_current_user_and_salon()
        return jsonify({"user": serialize_user(user), "salon": serialize_salon(salon)})

    @app.get("/api/users/me")
    @require_auth
    def get_my_user():
        user, salon = get_current_user_and_salon()
        return jsonify({"user": serialize_user(user), "salon": serialize_salon(salon)})

    @app.put("/api/users/me")
    @require_auth
    def update_my_user():
        data = request.get_json(silent=True) or {}
        full_name = clean_text(data.get("fullName") or data.get("full_name"))
        phone_number = clean_text(data.get("phoneNumber") or data.get("phone_number"))
        profile_image_url = clean_text(data.get("profileImageUrl") or data.get("profile_image_url"))

        if not full_name:
            return jsonify({"message": "Ime i prezime je obavezno."}), 400

        with get_db_cursor() as cursor:
            cursor.execute(
                """
                UPDATE users
                SET full_name = %s,
                    phone_number = %s,
                    profile_image_url = NULLIF(%s, '')
                WHERE id = %s
                RETURNING id, full_name, email, phone_number, profile_image_url, role
                """,
                (full_name, phone_number or None, profile_image_url, g.current_user_id),
            )
            user = cursor.fetchone()
        get_db_connection().commit()
        return jsonify({"user": serialize_user(user)})

    @app.post("/api/users/me/profile-image")
    @require_auth
    def update_my_profile_image():
        if request.files:
            saved = save_uploaded_image(request.files.get("image"), "profiles")
            if "error" in saved:
                return jsonify({"message": saved["error"]}), 400
            profile_image_url = saved["path"]
        else:
            data = request.get_json(silent=True) or {}
            profile_image_url = clean_text(data.get("profileImageUrl") or data.get("imageUrl") or data.get("url"))
        if not profile_image_url:
            return jsonify({"message": "URL slike je obavezan."}), 400

        with get_db_cursor() as cursor:
            cursor.execute(
                """
                UPDATE users
                SET profile_image_url = %s
                WHERE id = %s
                RETURNING id, full_name, email, phone_number, profile_image_url, role
                """,
                (profile_image_url, g.current_user_id),
            )
            user = cursor.fetchone()
        get_db_connection().commit()
        return jsonify({"user": serialize_user(user)})

    @app.get("/api/salons")
    def list_salons():
        city = clean_text(request.args.get("city"))
        min_rating = clean_text(request.args.get("minRating") or request.args.get("min_rating"))
        sort_by = clean_text(request.args.get("sortBy") or request.args.get("sort_by"))

        filters = ["s.is_active = TRUE"]
        params = []
        if city:
            filters.append("LOWER(s.city) LIKE LOWER(%s)")
            params.append(f"%{city}%")
        if min_rating:
            filters.append(
                "COALESCE((SELECT AVG(rating) FROM reviews WHERE reviewed_salon_id = s.id), 0) >= %s"
            )
            params.append(min_rating)

        order_by = "s.created_at DESC"
        if sort_by == "rating":
            order_by = "rating DESC, s.created_at DESC"
        elif sort_by == "name":
            order_by = "s.name ASC"

        with get_db_cursor() as cursor:
            cursor.execute(
                f"""
                SELECT s.*,
                    (
                        SELECT image_url
                        FROM salon_images si
                        WHERE si.salon_id = s.id
                        ORDER BY si.is_main DESC, si.sort_order ASC, si.created_at ASC
                        LIMIT 1
                    ) AS main_image_url,
                    COALESCE((
                        SELECT ROUND(AVG(rating)::numeric, 1)
                        FROM reviews
                        WHERE reviewed_salon_id = s.id
                    ), 0) AS rating,
                    COALESCE((
                        SELECT ARRAY_AGG(name ORDER BY name)
                        FROM services
                        WHERE salon_id = s.id AND is_active = TRUE
                    ), ARRAY[]::varchar[]) AS service_names,
                    (
                        SELECT MIN(price)
                        FROM services
                        WHERE salon_id = s.id AND is_active = TRUE AND price IS NOT NULL
                    ) AS min_price
                FROM salons s
                WHERE {' AND '.join(filters)}
                ORDER BY {order_by}
                """,
                tuple(params),
            )
            salons = cursor.fetchall()

        return jsonify({"salons": [serialize_salon(row) for row in salons]})

    @app.get("/api/salons/<salon_id>")
    def get_salon(salon_id):
        salon = fetch_salon(salon_id)
        if salon is None:
            return jsonify({"message": "Salon ne postoji."}), 404

        with get_db_cursor() as cursor:
            cursor.execute(
                "SELECT * FROM services WHERE salon_id = %s AND is_active = TRUE ORDER BY name",
                (salon_id,),
            )
            services = cursor.fetchall()
            cursor.execute(
                """
                SELECT *
                FROM salon_images
                WHERE salon_id = %s
                ORDER BY is_main DESC, sort_order ASC, created_at ASC
                """,
                (salon_id,),
            )
            images = cursor.fetchall()

        return jsonify(
            {
                "salon": serialize_salon(salon),
                "services": [serialize_service(row) for row in services],
                "images": [serialize_salon_image(row) for row in images],
            }
        )

    @app.post("/api/salons")
    @require_auth
    def create_salon():
        if g.current_user_role != "Barber":
            return jsonify({"message": "Samo frizer moze napraviti salon."}), 403

        data = request.get_json(silent=True) or {}
        payload = salon_payload(data)
        if not payload["name"] or not payload["address"]:
            return jsonify({"message": "Naziv i adresa salona su obavezni."}), 400

        with get_db_cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO salons (
                    owner_user_id, name, description, address, city, country,
                    latitude, longitude, phone_number, capacity, is_active
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING *
                """,
                (
                    g.current_user_id,
                    payload["name"],
                    payload["description"],
                    payload["address"],
                    payload["city"],
                    payload["country"],
                    payload["latitude"],
                    payload["longitude"],
                    payload["phone_number"],
                    payload["capacity"],
                    payload["is_active"],
                ),
            )
            salon = cursor.fetchone()
            create_default_working_hours(cursor, salon["id"])
        get_db_connection().commit()
        return jsonify({"salon": serialize_salon(salon)}), 201

    @app.put("/api/salons/<salon_id>")
    @require_auth
    def update_salon(salon_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error

        data = request.get_json(silent=True) or {}
        payload = salon_payload(data)
        if not payload["name"] or not payload["address"]:
            return jsonify({"message": "Naziv i adresa salona su obavezni."}), 400

        with get_db_cursor() as cursor:
            cursor.execute(
                """
                UPDATE salons
                SET name = %s,
                    description = %s,
                    address = %s,
                    city = %s,
                    country = %s,
                    latitude = %s,
                    longitude = %s,
                    phone_number = %s,
                    capacity = %s,
                    is_active = %s
                WHERE id = %s
                RETURNING *
                """,
                (
                    payload["name"],
                    payload["description"],
                    payload["address"],
                    payload["city"],
                    payload["country"],
                    payload["latitude"],
                    payload["longitude"],
                    payload["phone_number"],
                    payload["capacity"],
                    payload["is_active"],
                    salon_id,
                ),
            )
            salon = cursor.fetchone()
        get_db_connection().commit()
        return jsonify({"salon": serialize_salon(salon)})

    @app.delete("/api/salons/<salon_id>")
    @require_auth
    def delete_salon(salon_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        with get_db_cursor() as cursor:
            cursor.execute("DELETE FROM salons WHERE id = %s", (salon_id,))
        get_db_connection().commit()
        return jsonify({"message": "Salon je obrisan."})

    @app.get("/api/salons/<salon_id>/images")
    def list_salon_images(salon_id):
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                SELECT *
                FROM salon_images
                WHERE salon_id = %s
                ORDER BY is_main DESC, sort_order ASC, created_at ASC
                """,
                (salon_id,),
            )
            images = cursor.fetchall()
        return jsonify({"images": [serialize_salon_image(row) for row in images]})

    @app.post("/api/salons/<salon_id>/images")
    @require_auth
    def create_salon_image(salon_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        data = request.get_json(silent=True) or {}
        image_url = clean_text(data.get("imageUrl") or data.get("image_url") or data.get("url"))
        is_main = bool(data.get("isMain") or data.get("is_main") or False)
        if not image_url:
            return jsonify({"message": "URL slike je obavezan."}), 400

        connection = get_db_connection()
        with connection:
            with connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                if is_main:
                    cursor.execute("UPDATE salon_images SET is_main = FALSE WHERE salon_id = %s", (salon_id,))
                cursor.execute(
                    """
                    INSERT INTO salon_images (salon_id, image_url, is_main)
                    VALUES (%s, %s, %s)
                    RETURNING *
                    """,
                    (salon_id, image_url, is_main),
                )
                image = cursor.fetchone()
        return jsonify({"image": serialize_salon_image(image)}), 201

    @app.post("/api/salons/<salon_id>/images/upload")
    @require_auth
    def upload_salon_image(salon_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error

        saved = save_uploaded_image(request.files.get("image"), f"salons/{salon_id}")
        if "error" in saved:
            return jsonify({"message": saved["error"]}), 400

        is_main = str(request.form.get("isMain") or request.form.get("is_main") or "").lower() in {
            "true",
            "1",
            "yes",
        }

        connection = get_db_connection()
        with connection:
            with connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                if is_main:
                    cursor.execute("UPDATE salon_images SET is_main = FALSE WHERE salon_id = %s", (salon_id,))
                cursor.execute(
                    """
                    INSERT INTO salon_images (salon_id, image_url, is_main)
                    VALUES (%s, %s, %s)
                    RETURNING *
                    """,
                    (salon_id, saved["path"], is_main),
                )
                image = cursor.fetchone()
        return jsonify({"image": serialize_salon_image(image)}), 201

    @app.delete("/api/salons/<salon_id>/images/<image_id>")
    @require_auth
    def delete_salon_image(salon_id, image_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        with get_db_cursor() as cursor:
            cursor.execute("DELETE FROM salon_images WHERE salon_id = %s AND id = %s", (salon_id, image_id))
        get_db_connection().commit()
        return jsonify({"message": "Slika je obrisana."})

    @app.put("/api/salons/<salon_id>/images/<image_id>/main")
    @require_auth
    def set_main_salon_image(salon_id, image_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        connection = get_db_connection()
        with connection:
            with connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("UPDATE salon_images SET is_main = FALSE WHERE salon_id = %s", (salon_id,))
                cursor.execute(
                    """
                    UPDATE salon_images
                    SET is_main = TRUE
                    WHERE salon_id = %s AND id = %s
                    RETURNING *
                    """,
                    (salon_id, image_id),
                )
                image = cursor.fetchone()
        if image is None:
            return jsonify({"message": "Slika ne postoji."}), 404
        return jsonify({"image": serialize_salon_image(image)})

    @app.get("/api/salons/<salon_id>/services")
    def list_services(salon_id):
        with get_db_cursor() as cursor:
            cursor.execute(
                "SELECT * FROM services WHERE salon_id = %s ORDER BY is_active DESC, name ASC",
                (salon_id,),
            )
            services = cursor.fetchall()
        return jsonify({"services": [serialize_service(row) for row in services]})

    @app.post("/api/salons/<salon_id>/services")
    @require_auth
    def create_service(salon_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        data = request.get_json(silent=True) or {}
        payload = service_payload(data)
        error = validate_service_payload(payload)
        if error:
            return jsonify({"message": error}), 400

        with get_db_cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO services (salon_id, name, description, duration_minutes, price, is_active)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING *
                """,
                (
                    salon_id,
                    payload["name"],
                    payload["description"],
                    payload["duration_minutes"],
                    payload["price"],
                    payload["is_active"],
                ),
            )
            service = cursor.fetchone()
        get_db_connection().commit()
        return jsonify({"service": serialize_service(service)}), 201

    @app.put("/api/services/<service_id>")
    @require_auth
    def update_service(service_id):
        service = fetch_service(service_id)
        if service is None:
            return jsonify({"message": "Usluga ne postoji."}), 404
        owner_error = ensure_salon_owner(service["salon_id"])
        if owner_error:
            return owner_error
        data = request.get_json(silent=True) or {}
        payload = service_payload(data)
        error = validate_service_payload(payload)
        if error:
            return jsonify({"message": error}), 400

        with get_db_cursor() as cursor:
            cursor.execute(
                """
                UPDATE services
                SET name = %s,
                    description = %s,
                    duration_minutes = %s,
                    price = %s,
                    is_active = %s
                WHERE id = %s
                RETURNING *
                """,
                (
                    payload["name"],
                    payload["description"],
                    payload["duration_minutes"],
                    payload["price"],
                    payload["is_active"],
                    service_id,
                ),
            )
            updated = cursor.fetchone()
        get_db_connection().commit()
        return jsonify({"service": serialize_service(updated)})

    @app.delete("/api/services/<service_id>")
    @require_auth
    def delete_service(service_id):
        service = fetch_service(service_id)
        if service is None:
            return jsonify({"message": "Usluga ne postoji."}), 404
        owner_error = ensure_salon_owner(service["salon_id"])
        if owner_error:
            return owner_error
        with get_db_cursor() as cursor:
            cursor.execute("UPDATE services SET is_active = FALSE WHERE id = %s", (service_id,))
        get_db_connection().commit()
        return jsonify({"message": "Usluga je deaktivirana."})

    @app.get("/api/salons/<salon_id>/working-hours")
    def get_working_hours(salon_id):
        with get_db_cursor() as cursor:
            cursor.execute("SELECT * FROM working_hours WHERE salon_id = %s ORDER BY day_of_week", (salon_id,))
            rows = cursor.fetchall()
        return jsonify({"workingHours": [serialize_working_hour(row) for row in rows]})

    @app.put("/api/salons/<salon_id>/working-hours")
    @require_auth
    def put_working_hours(salon_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        data = request.get_json(silent=True) or {}
        hours = data.get("workingHours") or data.get("working_hours") or []
        if not isinstance(hours, list):
            return jsonify({"message": "workingHours mora biti lista."}), 400

        connection = get_db_connection()
        with connection:
            with connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                for item in hours:
                    day = int(item.get("dayOfWeek") or item.get("day_of_week"))
                    is_closed = bool(item.get("isClosed") or item.get("is_closed") or False)
                    start = clean_text(item.get("startTime") or item.get("start_time")) or None
                    end = clean_text(item.get("endTime") or item.get("end_time")) or None
                    if is_closed:
                        start = None
                        end = None
                    cursor.execute(
                        """
                        INSERT INTO working_hours (salon_id, day_of_week, start_time, end_time, is_closed)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (salon_id, day_of_week)
                        DO UPDATE SET start_time = EXCLUDED.start_time,
                                      end_time = EXCLUDED.end_time,
                                      is_closed = EXCLUDED.is_closed
                        """,
                        (salon_id, day, start, end, is_closed),
                    )
                cursor.execute("SELECT * FROM working_hours WHERE salon_id = %s ORDER BY day_of_week", (salon_id,))
                rows = cursor.fetchall()
        return jsonify({"workingHours": [serialize_working_hour(row) for row in rows]})

    @app.get("/api/salons/<salon_id>/breaks")
    def list_breaks(salon_id):
        with get_db_cursor() as cursor:
            cursor.execute(
                "SELECT * FROM salon_breaks WHERE salon_id = %s ORDER BY day_of_week, start_time",
                (salon_id,),
            )
            rows = cursor.fetchall()
        return jsonify({"breaks": [serialize_break(row) for row in rows]})

    @app.post("/api/salons/<salon_id>/breaks")
    @require_auth
    def create_break(salon_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        data = request.get_json(silent=True) or {}
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO salon_breaks (salon_id, day_of_week, start_time, end_time, reason)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING *
                """,
                (
                    salon_id,
                    int(data.get("dayOfWeek") or data.get("day_of_week")),
                    clean_text(data.get("startTime") or data.get("start_time")),
                    clean_text(data.get("endTime") or data.get("end_time")),
                    clean_text(data.get("reason")) or None,
                ),
            )
            row = cursor.fetchone()
        get_db_connection().commit()
        return jsonify({"break": serialize_break(row)}), 201

    @app.put("/api/salons/<salon_id>/breaks/<break_id>")
    @require_auth
    def update_break(salon_id, break_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        data = request.get_json(silent=True) or {}
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                UPDATE salon_breaks
                SET day_of_week = %s, start_time = %s, end_time = %s, reason = %s
                WHERE salon_id = %s AND id = %s
                RETURNING *
                """,
                (
                    int(data.get("dayOfWeek") or data.get("day_of_week")),
                    clean_text(data.get("startTime") or data.get("start_time")),
                    clean_text(data.get("endTime") or data.get("end_time")),
                    clean_text(data.get("reason")) or None,
                    salon_id,
                    break_id,
                ),
            )
            row = cursor.fetchone()
        get_db_connection().commit()
        if row is None:
            return jsonify({"message": "Pauza ne postoji."}), 404
        return jsonify({"break": serialize_break(row)})

    @app.delete("/api/salons/<salon_id>/breaks/<break_id>")
    @require_auth
    def delete_break(salon_id, break_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        with get_db_cursor() as cursor:
            cursor.execute("DELETE FROM salon_breaks WHERE salon_id = %s AND id = %s", (salon_id, break_id))
        get_db_connection().commit()
        return jsonify({"message": "Pauza je obrisana."})

    @app.get("/api/favorites")
    @require_auth
    def list_favorites():
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                SELECT s.*,
                    (
                        SELECT image_url
                        FROM salon_images si
                        WHERE si.salon_id = s.id
                        ORDER BY si.is_main DESC, si.sort_order ASC, si.created_at ASC
                        LIMIT 1
                    ) AS main_image_url,
                    COALESCE((
                        SELECT ROUND(AVG(rating)::numeric, 1)
                        FROM reviews
                        WHERE reviewed_salon_id = s.id
                    ), 0) AS rating,
                    COALESCE((
                        SELECT ARRAY_AGG(name ORDER BY name)
                        FROM services
                        WHERE salon_id = s.id AND is_active = TRUE
                    ), ARRAY[]::varchar[]) AS service_names,
                    (
                        SELECT MIN(price)
                        FROM services
                        WHERE salon_id = s.id AND is_active = TRUE AND price IS NOT NULL
                    ) AS min_price
                FROM favorite_salons fs
                JOIN salons s ON s.id = fs.salon_id
                WHERE fs.customer_id = %s
                ORDER BY fs.created_at DESC
                """,
                (g.current_user_id,),
            )
            rows = cursor.fetchall()
        return jsonify({"salons": [serialize_salon(row) for row in rows]})

    @app.post("/api/favorites/<salon_id>")
    @require_auth
    def add_favorite(salon_id):
        if g.current_user_role != "Customer":
            return jsonify({"message": "Samo korisnik moze dodati favorite."}), 403
        with get_db_cursor() as cursor:
            cursor.execute("SELECT id FROM salons WHERE id = %s AND is_active = TRUE", (salon_id,))
            if cursor.fetchone() is None:
                return jsonify({"message": "Salon ne postoji."}), 404
            cursor.execute(
                """
                INSERT INTO favorite_salons (customer_id, salon_id)
                VALUES (%s, %s)
                ON CONFLICT (customer_id, salon_id) DO NOTHING
                """,
                (g.current_user_id, salon_id),
            )
        get_db_connection().commit()
        return jsonify({"message": "Salon je dodan u favorite."})

    @app.delete("/api/favorites/<salon_id>")
    @require_auth
    def remove_favorite(salon_id):
        with get_db_cursor() as cursor:
            cursor.execute(
                "DELETE FROM favorite_salons WHERE customer_id = %s AND salon_id = %s",
                (g.current_user_id, salon_id),
            )
        get_db_connection().commit()
        return jsonify({"message": "Salon je uklonjen iz favorita."})

    @app.get("/api/salons/<salon_id>/available-slots")
    def available_slots(salon_id):
        service_id = clean_text(request.args.get("serviceId") or request.args.get("service_id"))
        date_value = clean_text(request.args.get("date")) or date.today().isoformat()
        if not service_id:
            return jsonify({"message": "serviceId je obavezan."}), 400
        try:
            slots_date = date.fromisoformat(date_value)
        except ValueError:
            return jsonify({"message": "Datum mora biti YYYY-MM-DD."}), 400

        result = generate_available_slots(salon_id, service_id, slots_date)
        if isinstance(result, tuple):
            return result
        return jsonify({"date": date_value, "slots": result})

    @app.post("/api/reservations")
    @require_auth
    def create_reservation():
        if g.current_user_role != "Customer":
            return jsonify({"message": "Samo korisnik moze rezervisati termin."}), 403
        data = request.get_json(silent=True) or {}
        salon_id = clean_text(data.get("salonId") or data.get("salon_id"))
        service_id = clean_text(data.get("serviceId") or data.get("service_id"))
        start = parse_client_datetime(data.get("startTime") or data.get("start_time"))
        if not salon_id or not service_id or start is None:
            return jsonify({"message": "salonId, serviceId i startTime su obavezni."}), 400

        result = validate_reservation_request(g.current_user_id, salon_id, service_id, start)
        if "error" in result:
            return jsonify({"message": result["error"]}), result.get("status", 400)

        salon = result["salon"]
        end = result["end_time"]

        connection = get_db_connection()
        try:
            with connection:
                with connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                    cursor.execute(
                        """
                        INSERT INTO reservations (customer_id, salon_id, service_id, start_time, end_time, status)
                        VALUES (%s, %s, %s, %s, %s, 'Pending')
                        RETURNING *
                        """,
                        (g.current_user_id, salon_id, service_id, start, end),
                    )
                    reservation = cursor.fetchone()
                    cursor.execute(
                        """
                        INSERT INTO notifications (user_id, reservation_id, title, message)
                        VALUES (%s, %s, %s, %s)
                        """,
                        (
                            salon["owner_user_id"],
                            reservation["id"],
                            "Novi zahtjev za termin",
                            "Korisnik zeli termin u salonu %s." % salon["name"],
                        ),
                    )
        except errors.UniqueViolation:
            connection.rollback()
            return jsonify({"message": "Vec imate aktivnu rezervaciju."}), 409

        return jsonify(
            {
                "reservation": serialize_reservation(reservation),
                "message": "Zahtjev za termin je poslan salonu.",
            }
        ), 201

    @app.get("/api/reservations/my")
    @require_auth
    def my_reservations():
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                SELECT r.*, s.name AS salon_name, sv.name AS service_name, sv.duration_minutes
                FROM reservations r
                JOIN salons s ON s.id = r.salon_id
                JOIN services sv ON sv.id = r.service_id
                WHERE r.customer_id = %s
                ORDER BY r.start_time DESC
                """,
                (g.current_user_id,),
            )
            rows = cursor.fetchall()
        return jsonify({"reservations": [serialize_reservation(row) for row in rows]})

    @app.get("/api/salons/<salon_id>/reservations")
    @require_auth
    def salon_reservations(salon_id):
        owner_error = ensure_salon_owner(salon_id)
        if owner_error:
            return owner_error
        status = clean_text(request.args.get("status"))
        params = [salon_id]
        status_filter = ""
        if status:
            status_filter = "AND r.status = %s"
            params.append(status)

        with get_db_cursor() as cursor:
            cursor.execute(
                f"""
                SELECT r.*,
                       u.full_name AS customer_name,
                       u.email AS customer_email,
                       sv.name AS service_name,
                       sv.duration_minutes,
                       cr.completed_count,
                       cr.cancelled_late_count,
                       cr.no_show_count,
                       cr.reliability_status
                FROM reservations r
                JOIN users u ON u.id = r.customer_id
                JOIN services sv ON sv.id = r.service_id
                LEFT JOIN customer_reliability cr ON cr.customer_id = r.customer_id
                WHERE r.salon_id = %s
                {status_filter}
                ORDER BY r.start_time ASC
                """,
                tuple(params),
            )
            rows = cursor.fetchall()
        return jsonify({"reservations": [serialize_reservation(row) for row in rows]})

    @app.post("/api/reservations/<reservation_id>/accept")
    @require_auth
    def accept_reservation(reservation_id):
        return update_reservation_by_salon(reservation_id, "Accepted")

    @app.post("/api/reservations/<reservation_id>/reject")
    @require_auth
    def reject_reservation(reservation_id):
        return update_reservation_by_salon(reservation_id, "Rejected")

    @app.post("/api/reservations/<reservation_id>/complete")
    @require_auth
    def complete_reservation(reservation_id):
        return update_reservation_by_salon(reservation_id, "Completed")

    @app.post("/api/reservations/<reservation_id>/no-show")
    @require_auth
    def no_show_reservation(reservation_id):
        return update_reservation_by_salon(reservation_id, "NoShow")

    @app.post("/api/reservations/<reservation_id>/cancel")
    @require_auth
    def cancel_reservation(reservation_id):
        with get_db_cursor() as cursor:
            cursor.execute("SELECT * FROM reservations WHERE id = %s", (reservation_id,))
            reservation = cursor.fetchone()
            if reservation is None:
                return jsonify({"message": "Rezervacija ne postoji."}), 404
            if str(reservation["customer_id"]) != str(g.current_user_id):
                return jsonify({"message": "Nemate pravo otkazati ovu rezervaciju."}), 403
            if reservation["status"] not in ACTIVE_STATUSES:
                return jsonify({"message": "Rezervacija se ne moze otkazati."}), 400

            hours_until_start = reservation["start_time"] - datetime.now(timezone.utc)
            new_status = "CancelledLate" if hours_until_start < timedelta(hours=3) else "CancelledByUser"
            cursor.execute(
                """
                UPDATE reservations
                SET status = %s, cancelled_at = NOW()
                WHERE id = %s
                RETURNING *
                """,
                (new_status, reservation_id),
            )
            updated = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO notifications (user_id, reservation_id, title, message)
                SELECT s.owner_user_id, %s, %s, %s
                FROM salons s
                WHERE s.id = %s
                """,
                (reservation_id, "Termin otkazan", "Korisnik je otkazao termin.", reservation["salon_id"]),
            )
        get_db_connection().commit()
        return jsonify({"reservation": serialize_reservation(updated)})

    @app.get("/api/notifications")
    @require_auth
    def list_notifications():
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                SELECT *
                FROM notifications
                WHERE user_id = %s
                ORDER BY created_at DESC
                LIMIT 100
                """,
                (g.current_user_id,),
            )
            rows = cursor.fetchall()
        return jsonify({"notifications": [serialize_notification(row) for row in rows]})

    @app.post("/api/notifications/<notification_id>/read")
    @require_auth
    def mark_notification_read(notification_id):
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                UPDATE notifications
                SET is_read = TRUE, read_at = NOW()
                WHERE id = %s AND user_id = %s
                RETURNING *
                """,
                (notification_id, g.current_user_id),
            )
            row = cursor.fetchone()
        get_db_connection().commit()
        if row is None:
            return jsonify({"message": "Notifikacija ne postoji."}), 404
        return jsonify({"notification": serialize_notification(row)})

    @app.post("/api/notifications/read-all")
    @require_auth
    def mark_all_notifications_read():
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                UPDATE notifications
                SET is_read = TRUE, read_at = NOW()
                WHERE user_id = %s AND is_read = FALSE
                """,
                (g.current_user_id,),
            )
        get_db_connection().commit()
        return jsonify({"message": "Sve notifikacije su procitane."})

    @app.post("/api/reviews")
    @require_auth
    def create_review():
        data = request.get_json(silent=True) or {}
        reservation_id = clean_text(data.get("reservationId") or data.get("reservation_id"))
        rating = int(data.get("rating") or 0)
        comment = clean_text(data.get("comment")) or None
        if rating < 1 or rating > 5:
            return jsonify({"message": "Ocjena mora biti od 1 do 5."}), 400

        with get_db_cursor() as cursor:
            cursor.execute("SELECT * FROM reservations WHERE id = %s", (reservation_id,))
            reservation = cursor.fetchone()
            if reservation is None:
                return jsonify({"message": "Rezervacija ne postoji."}), 404
            if reservation["status"] != "Completed":
                return jsonify({"message": "Ocjena je moguca samo nakon zavrsenog termina."}), 400
            if str(reservation["customer_id"]) != str(g.current_user_id):
                return jsonify({"message": "Mozete ocijeniti samo svoj termin."}), 403
            cursor.execute(
                """
                INSERT INTO reviews (reservation_id, reviewer_user_id, reviewed_salon_id, rating, comment)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING *
                """,
                (reservation_id, g.current_user_id, reservation["salon_id"], rating, comment),
            )
            review = cursor.fetchone()
        get_db_connection().commit()
        return jsonify({"review": serialize_review(review)}), 201

    @app.get("/api/salons/<salon_id>/reviews")
    def salon_reviews(salon_id):
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                SELECT rv.*, u.full_name AS reviewer_name
                FROM reviews rv
                JOIN users u ON u.id = rv.reviewer_user_id
                WHERE rv.reviewed_salon_id = %s
                ORDER BY rv.created_at DESC
                """,
                (salon_id,),
            )
            rows = cursor.fetchall()
        return jsonify({"reviews": [serialize_review(row) for row in rows]})

    @app.get("/api/users/<user_id>/reviews")
    @require_auth
    def user_reviews(user_id):
        with get_db_cursor() as cursor:
            cursor.execute(
                """
                SELECT rv.*, u.full_name AS reviewer_name
                FROM reviews rv
                JOIN users u ON u.id = rv.reviewer_user_id
                WHERE rv.reviewed_user_id = %s
                ORDER BY rv.created_at DESC
                """,
                (user_id,),
            )
            rows = cursor.fetchall()
        return jsonify({"reviews": [serialize_review(row) for row in rows]})

    return app


def get_db_connection():
    connection = g.get("db_connection")
    if connection is None:
        connection = psycopg2.connect(DATABASE_URL)
        g.db_connection = connection
    return connection


def get_db_cursor():
    return get_db_connection().cursor(cursor_factory=psycopg2.extras.RealDictCursor)


def require_auth(route):
    @wraps(route)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return jsonify({"message": "Nedostaje token."}), 401

        token = header[len("Bearer ") :].strip()
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        except jwt.ExpiredSignatureError:
            return jsonify({"message": "Token je istekao."}), 401
        except jwt.InvalidTokenError:
            return jsonify({"message": "Neispravan token."}), 401

        g.current_user_id = payload["sub"]
        g.current_user_role = payload["role"]
        return route(*args, **kwargs)

    return wrapper


def create_token(user_id, role):
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": str(role),
        "iat": now,
        "exp": now + timedelta(days=TOKEN_DAYS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def clean_text(value):
    if value is None:
        return ""
    return str(value).strip()


def ensure_upload_dirs():
    os.makedirs(os.path.join(UPLOAD_DIR, "profiles"), exist_ok=True)
    os.makedirs(os.path.join(UPLOAD_DIR, "salons"), exist_ok=True)


def save_uploaded_image(file_storage, subdir):
    if file_storage is None or not file_storage.filename:
        return {"error": "Slika je obavezna."}

    original_name = secure_filename(file_storage.filename)
    extension = original_name.rsplit(".", 1)[-1].lower() if "." in original_name else ""
    if extension not in ALLOWED_IMAGE_EXTENSIONS:
        return {"error": "Dozvoljene slike su JPG, PNG, WEBP ili GIF."}

    target_dir = os.path.join(UPLOAD_DIR, subdir)
    os.makedirs(target_dir, exist_ok=True)
    filename = f"{uuid4().hex}.{extension}"
    absolute_path = os.path.join(target_dir, filename)
    file_storage.save(absolute_path)

    relative_subdir = subdir.replace("\\", "/").strip("/")
    return {"path": f"/uploads/{relative_subdir}/{filename}"}


def public_file_url(path):
    if not path:
        return None
    if str(path).startswith(("http://", "https://")):
        return path
    base = os.getenv("PUBLIC_BASE_URL", "").rstrip("/")
    if not base:
        base = request.host_url.rstrip("/")
    return base + "/" + str(path).lstrip("/")


def normalize_role(value):
    normalized = clean_text(value).lower()
    if normalized in {"salon", "barber", "frizer"}:
        return "Barber"
    if normalized == "admin":
        return "Admin"
    return "Customer"


def validate_register_payload(role, full_name, email, password, salon_name, salon_address):
    payload_errors = {}
    if not full_name:
        payload_errors["fullName"] = "Ime i prezime je obavezno."
    if not email or "@" not in email:
        payload_errors["email"] = "Unesi ispravan email."
    if len(password) < 6:
        payload_errors["password"] = "Lozinka mora imati najmanje 6 karaktera."
    if role == "Barber":
        if not salon_name:
            payload_errors["salonName"] = "Naziv salona je obavezan."
        if not salon_address:
            payload_errors["salonAddress"] = "Adresa salona je obavezna."
    return payload_errors


def get_current_user_and_salon():
    with get_db_cursor() as cursor:
        cursor.execute(
            """
            SELECT id, full_name, email, phone_number, profile_image_url, role
            FROM users
            WHERE id = %s
            """,
            (g.current_user_id,),
        )
        user = cursor.fetchone()
        if user is None:
            return None, None
        salon = fetch_owner_salon(cursor, user["id"]) if user["role"] == "Barber" else None
    return user, salon


def fetch_owner_salon(cursor, user_id):
    cursor.execute(
        """
        SELECT *
        FROM salons
        WHERE owner_user_id = %s
        ORDER BY created_at ASC
        LIMIT 1
        """,
        (user_id,),
    )
    return cursor.fetchone()


def fetch_salon(salon_id):
    with get_db_cursor() as cursor:
        cursor.execute(
            """
            SELECT s.*,
                (
                    SELECT image_url
                    FROM salon_images si
                    WHERE si.salon_id = s.id
                    ORDER BY si.is_main DESC, si.sort_order ASC, si.created_at ASC
                    LIMIT 1
                ) AS main_image_url,
                COALESCE((
                    SELECT ROUND(AVG(rating)::numeric, 1)
                    FROM reviews
                    WHERE reviewed_salon_id = s.id
                ), 0) AS rating
            FROM salons s
            WHERE s.id = %s
            """,
            (salon_id,),
        )
        return cursor.fetchone()


def fetch_service(service_id):
    with get_db_cursor() as cursor:
        cursor.execute("SELECT * FROM services WHERE id = %s", (service_id,))
        return cursor.fetchone()


def ensure_salon_owner(salon_id):
    salon = fetch_salon(salon_id)
    if salon is None:
        return jsonify({"message": "Salon ne postoji."}), 404
    if str(salon["owner_user_id"]) != str(g.current_user_id):
        return jsonify({"message": "Nemate pravo mijenjati ovaj salon."}), 403
    return None


def salon_payload(data):
    return {
        "name": clean_text(data.get("name")),
        "description": clean_text(data.get("description")) or None,
        "address": clean_text(data.get("address")),
        "city": clean_text(data.get("city")) or None,
        "country": clean_text(data.get("country")) or "BiH",
        "latitude": numeric_or_none(data.get("latitude")),
        "longitude": numeric_or_none(data.get("longitude")),
        "phone_number": clean_text(data.get("phoneNumber") or data.get("phone_number")) or None,
        "capacity": max(1, int(data.get("capacity") or 1)),
        "is_active": bool(data.get("isActive", data.get("is_active", True))),
    }


def service_payload(data):
    return {
        "name": clean_text(data.get("name")),
        "description": clean_text(data.get("description")) or None,
        "duration_minutes": int(data.get("durationMinutes") or data.get("duration_minutes") or 0),
        "price": numeric_or_none(data.get("price")),
        "is_active": bool(data.get("isActive", data.get("is_active", True))),
    }


def validate_service_payload(payload):
    if not payload["name"]:
        return "Naziv usluge je obavezan."
    if payload["duration_minutes"] <= 0:
        return "Trajanje usluge mora biti vece od 0."
    if payload["price"] is not None and payload["price"] < 0:
        return "Cijena ne moze biti negativna."
    return None


def numeric_or_none(value):
    if value in (None, ""):
        return None
    return Decimal(str(value))


def create_default_working_hours(cursor, salon_id):
    defaults = [
        (1, "09:00", "17:00", False),
        (2, "09:00", "17:00", False),
        (3, "09:00", "17:00", False),
        (4, "09:00", "17:00", False),
        (5, "09:00", "17:00", False),
        (6, "09:00", "14:00", False),
        (7, None, None, True),
    ]
    for day, start, end, closed in defaults:
        cursor.execute(
            """
            INSERT INTO working_hours (salon_id, day_of_week, start_time, end_time, is_closed)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (salon_id, day_of_week) DO NOTHING
            """,
            (salon_id, day, start, end, closed),
        )


def parse_client_datetime(value):
    if not value:
        return None
    raw = clean_text(value).replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(raw)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def validate_reservation_request(customer_id, salon_id, service_id, start):
    with get_db_cursor() as cursor:
        cursor.execute(
            "SELECT COUNT(*) AS count FROM reservations WHERE customer_id = %s AND status IN %s",
            (customer_id, ACTIVE_STATUSES),
        )
        if cursor.fetchone()["count"] > 0:
            return {"error": "Vec imate aktivnu rezervaciju.", "status": 409}

        cursor.execute("SELECT * FROM salons WHERE id = %s AND is_active = TRUE", (salon_id,))
        salon = cursor.fetchone()
        if salon is None:
            return {"error": "Salon ne postoji ili nije aktivan.", "status": 404}

        cursor.execute(
            "SELECT * FROM services WHERE id = %s AND salon_id = %s AND is_active = TRUE",
            (service_id, salon_id),
        )
        service = cursor.fetchone()
        if service is None:
            return {"error": "Usluga ne postoji za ovaj salon.", "status": 404}

        end = start + timedelta(minutes=service["duration_minutes"])
        availability_error = validate_open_and_capacity(cursor, salon, service, start, end)
        if availability_error:
            return {"error": availability_error, "status": 400}

    return {"salon": salon, "service": service, "end_time": end}


def validate_open_and_capacity(cursor, salon, service, start, end):
    day = start.isoweekday()
    cursor.execute("SELECT * FROM working_hours WHERE salon_id = %s AND day_of_week = %s", (salon["id"], day))
    working = cursor.fetchone() or default_working_hour(day)
    if working["is_closed"]:
        return "Salon ne radi taj dan."
    if start.time() < working["start_time"] or end.time() > working["end_time"]:
        return "Salon ne radi u tom terminu."

    cursor.execute(
        """
        SELECT *
        FROM salon_breaks
        WHERE salon_id = %s
          AND day_of_week = %s
          AND start_time < %s
          AND end_time > %s
        """,
        (salon["id"], day, end.time(), start.time()),
    )
    if cursor.fetchone() is not None:
        return "Termin je u pauzi salona."

    cursor.execute(
        """
        SELECT COUNT(*) AS count
        FROM reservations
        WHERE salon_id = %s
          AND status IN %s
          AND start_time < %s
          AND end_time > %s
        """,
        (salon["id"], ACTIVE_STATUSES, end, start),
    )
    if cursor.fetchone()["count"] >= salon["capacity"]:
        return "Termin je zauzet."
    return None


def default_working_hour(day):
    if day == 7:
        return {"is_closed": True, "start_time": None, "end_time": None}
    if day == 6:
        return {"is_closed": False, "start_time": time(9, 0), "end_time": time(14, 0)}
    return {"is_closed": False, "start_time": time(9, 0), "end_time": time(17, 0)}


def generate_available_slots(salon_id, service_id, slots_date):
    with get_db_cursor() as cursor:
        cursor.execute("SELECT * FROM salons WHERE id = %s AND is_active = TRUE", (salon_id,))
        salon = cursor.fetchone()
        if salon is None:
            return jsonify({"message": "Salon ne postoji ili nije aktivan."}), 404

        cursor.execute(
            "SELECT * FROM services WHERE id = %s AND salon_id = %s AND is_active = TRUE",
            (service_id, salon_id),
        )
        service = cursor.fetchone()
        if service is None:
            return jsonify({"message": "Usluga ne postoji za ovaj salon."}), 404

        day = slots_date.isoweekday()
        cursor.execute("SELECT * FROM working_hours WHERE salon_id = %s AND day_of_week = %s", (salon_id, day))
        working = cursor.fetchone() or default_working_hour(day)
        if working["is_closed"]:
            return []

        start_dt = datetime.combine(slots_date, working["start_time"], tzinfo=timezone.utc)
        end_dt = datetime.combine(slots_date, working["end_time"], tzinfo=timezone.utc)
        step = timedelta(minutes=service["duration_minutes"])
        slots = []
        current = start_dt
        while current + step <= end_dt:
            slot_end = current + step
            if not slot_overlaps_break(cursor, salon_id, day, current.time(), slot_end.time()):
                cursor.execute(
                    """
                    SELECT COUNT(*) AS count
                    FROM reservations
                    WHERE salon_id = %s
                      AND status IN %s
                      AND start_time < %s
                      AND end_time > %s
                    """,
                    (salon_id, ACTIVE_STATUSES, slot_end, current),
                )
                taken = cursor.fetchone()["count"]
                slots.append(
                    {
                        "startTime": current.isoformat(),
                        "endTime": slot_end.isoformat(),
                        "capacity": salon["capacity"],
                        "taken": taken,
                        "available": max(0, salon["capacity"] - taken),
                    }
                )
            current = slot_end
    return slots


def slot_overlaps_break(cursor, salon_id, day, start_time, end_time):
    cursor.execute(
        """
        SELECT 1
        FROM salon_breaks
        WHERE salon_id = %s
          AND day_of_week = %s
          AND start_time < %s
          AND end_time > %s
        LIMIT 1
        """,
        (salon_id, day, end_time, start_time),
    )
    return cursor.fetchone() is not None


def update_reservation_by_salon(reservation_id, new_status):
    with get_db_cursor() as cursor:
        cursor.execute(
            """
            SELECT r.*, s.owner_user_id, s.name AS salon_name, s.capacity
            FROM reservations r
            JOIN salons s ON s.id = r.salon_id
            WHERE r.id = %s
            """,
            (reservation_id,),
        )
        reservation = cursor.fetchone()
        if reservation is None:
            return jsonify({"message": "Rezervacija ne postoji."}), 404
        if str(reservation["owner_user_id"]) != str(g.current_user_id):
            return jsonify({"message": "Nemate pravo mijenjati ovu rezervaciju."}), 403

        if new_status in ("Accepted", "Rejected") and reservation["status"] != "Pending":
            return jsonify({"message": "Rezervacija nije Pending."}), 400
        if new_status in ("Completed", "NoShow") and reservation["status"] != "Accepted":
            return jsonify({"message": "Rezervacija mora biti Accepted."}), 400

        timestamp_column = {
            "Accepted": "accepted_at",
            "Rejected": "rejected_at",
            "Completed": "completed_at",
            "NoShow": "completed_at",
        }[new_status]

        cursor.execute(
            f"""
            UPDATE reservations
            SET status = %s,
                {timestamp_column} = NOW()
            WHERE id = %s
            RETURNING *
            """,
            (new_status, reservation_id),
        )
        updated = cursor.fetchone()

        title = {
            "Accepted": "Termin prihvacen",
            "Rejected": "Termin odbijen",
            "Completed": "Termin zavrsen",
            "NoShow": "Oznacen nedolazak",
        }[new_status]
        message = {
            "Accepted": "Salon %s je prihvatio vas termin." % reservation["salon_name"],
            "Rejected": "Salon %s je odbio vas zahtjev za termin." % reservation["salon_name"],
            "Completed": "Kako biste ocijenili salon %s?" % reservation["salon_name"],
            "NoShow": "Salon %s je oznacio da se niste pojavili." % reservation["salon_name"],
        }[new_status]
        cursor.execute(
            """
            INSERT INTO notifications (user_id, reservation_id, title, message)
            VALUES (%s, %s, %s, %s)
            """,
            (reservation["customer_id"], reservation_id, title, message),
        )
    get_db_connection().commit()
    return jsonify({"reservation": serialize_reservation(updated)})


def serialize_user(user):
    if user is None:
        return None
    return {
        "id": str(user["id"]),
        "fullName": user["full_name"],
        "email": user["email"],
        "phoneNumber": user["phone_number"],
        "profileImageUrl": public_file_url(user.get("profile_image_url")),
        "role": user["role"],
    }


def serialize_salon(salon):
    if salon is None:
        return None
    return {
        "id": str(salon["id"]),
        "ownerUserId": str(salon["owner_user_id"]),
        "name": salon["name"],
        "description": salon.get("description"),
        "address": salon["address"],
        "city": salon.get("city"),
        "country": salon.get("country"),
        "latitude": decimal_to_float(salon.get("latitude")),
        "longitude": decimal_to_float(salon.get("longitude")),
        "phoneNumber": salon.get("phone_number"),
        "capacity": salon["capacity"],
        "isActive": salon["is_active"],
        "rating": decimal_to_float(salon.get("rating", 0)),
        "mainImageUrl": public_file_url(salon.get("main_image_url")),
        "services": list(salon.get("service_names") or []),
        "minPrice": decimal_to_float(salon.get("min_price")),
    }


def serialize_salon_image(row):
    return {
        "id": str(row["id"]),
        "salonId": str(row["salon_id"]),
        "imageUrl": public_file_url(row["image_url"]),
        "isMain": row["is_main"],
        "sortOrder": row["sort_order"],
        "createdAt": row["created_at"].isoformat(),
    }


def serialize_service(row):
    return {
        "id": str(row["id"]),
        "salonId": str(row["salon_id"]),
        "name": row["name"],
        "description": row.get("description"),
        "durationMinutes": row["duration_minutes"],
        "price": decimal_to_float(row.get("price")),
        "isActive": row["is_active"],
    }


def serialize_working_hour(row):
    return {
        "id": str(row["id"]),
        "salonId": str(row["salon_id"]),
        "dayOfWeek": row["day_of_week"],
        "startTime": row["start_time"].strftime("%H:%M") if row["start_time"] else None,
        "endTime": row["end_time"].strftime("%H:%M") if row["end_time"] else None,
        "isClosed": row["is_closed"],
    }


def serialize_break(row):
    return {
        "id": str(row["id"]),
        "salonId": str(row["salon_id"]),
        "dayOfWeek": row["day_of_week"],
        "startTime": row["start_time"].strftime("%H:%M"),
        "endTime": row["end_time"].strftime("%H:%M"),
        "reason": row.get("reason"),
    }


def serialize_reservation(row):
    payload = {
        "id": str(row["id"]),
        "customerId": str(row["customer_id"]),
        "salonId": str(row["salon_id"]),
        "serviceId": str(row["service_id"]),
        "startTime": row["start_time"].isoformat(),
        "endTime": row["end_time"].isoformat(),
        "status": row["status"],
        "cancellationReason": row.get("cancellation_reason"),
        "salonName": row.get("salon_name"),
        "serviceName": row.get("service_name"),
        "customerName": row.get("customer_name"),
        "customerEmail": row.get("customer_email"),
        "durationMinutes": row.get("duration_minutes"),
        "reliabilityStatus": row.get("reliability_status"),
        "completedCount": row.get("completed_count"),
        "cancelledLateCount": row.get("cancelled_late_count"),
        "noShowCount": row.get("no_show_count"),
    }
    return payload


def serialize_notification(row):
    return {
        "id": str(row["id"]),
        "userId": str(row["user_id"]),
        "reservationId": str(row["reservation_id"]) if row.get("reservation_id") else None,
        "title": row["title"],
        "message": row["message"],
        "isRead": row["is_read"],
        "readAt": row["read_at"].isoformat() if row.get("read_at") else None,
        "createdAt": row["created_at"].isoformat(),
    }


def serialize_review(row):
    return {
        "id": str(row["id"]),
        "reservationId": str(row["reservation_id"]),
        "reviewerUserId": str(row["reviewer_user_id"]),
        "reviewedUserId": str(row["reviewed_user_id"]) if row.get("reviewed_user_id") else None,
        "reviewedSalonId": str(row["reviewed_salon_id"]) if row.get("reviewed_salon_id") else None,
        "rating": row["rating"],
        "comment": row.get("comment"),
        "reviewerName": row.get("reviewer_name"),
        "createdAt": row["created_at"].isoformat(),
    }


def decimal_to_float(value):
    if value is None:
        return None
    if isinstance(value, Decimal):
        return float(value)
    return value


app = create_app()


if __name__ == "__main__":
    app.run(
        host=os.getenv("FLASK_HOST", "127.0.0.1"),
        port=int(os.getenv("FLASK_PORT", "5001")),
        debug=os.getenv("FLASK_DEBUG", "true").lower() == "true",
    )
