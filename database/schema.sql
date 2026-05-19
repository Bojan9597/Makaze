CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('Customer', 'Barber', 'Admin');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reservation_status') THEN
        CREATE TYPE reservation_status AS ENUM (
            'Pending',
            'Accepted',
            'Rejected',
            'CancelledByUser',
            'CancelledByBarber',
            'CancelledLate',
            'Completed',
            'NoShow',
            'Expired'
        );
    END IF;
END $$;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    full_name VARCHAR(150) NOT NULL,
    email CITEXT NOT NULL UNIQUE,
    phone_number VARCHAR(50),

    password_hash TEXT NOT NULL,
    profile_image_url TEXT,

    role user_role NOT NULL DEFAULT 'Customer',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS salons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    name VARCHAR(150) NOT NULL,
    description TEXT,

    address TEXT NOT NULL,
    city VARCHAR(100),
    country VARCHAR(100),

    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),

    phone_number VARCHAR(50),

    capacity INT NOT NULL DEFAULT 1 CHECK (capacity > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS salon_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

    image_url TEXT NOT NULL,
    is_main BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS barbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,

    name VARCHAR(150) NOT NULL,
    description TEXT,
    profile_image_url TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,

    UNIQUE (id, salon_id)
);

CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

    name VARCHAR(150) NOT NULL,
    description TEXT,

    duration_minutes INT NOT NULL CHECK (duration_minutes > 0),
    price NUMERIC(10, 2) CHECK (price IS NULL OR price >= 0),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,

    UNIQUE (id, salon_id)
);

CREATE TABLE IF NOT EXISTS working_hours (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),

    start_time TIME,
    end_time TIME,

    is_closed BOOLEAN NOT NULL DEFAULT FALSE,

    UNIQUE (salon_id, day_of_week),
    CHECK (
        (is_closed = TRUE AND start_time IS NULL AND end_time IS NULL)
        OR
        (is_closed = FALSE AND start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)
    )
);

CREATE TABLE IF NOT EXISTS salon_breaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),

    start_time TIME NOT NULL,
    end_time TIME NOT NULL,

    reason VARCHAR(150),

    CHECK (end_time > start_time)
);

CREATE TABLE IF NOT EXISTS favorite_salons (
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (customer_id, salon_id)
);

CREATE TABLE IF NOT EXISTS reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
    barber_id UUID,
    service_id UUID NOT NULL,

    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,

    status reservation_status NOT NULL DEFAULT 'Pending',
    cancellation_reason TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,

    accepted_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    CHECK (end_time > start_time),

    FOREIGN KEY (service_id, salon_id)
        REFERENCES services(id, salon_id)
        ON DELETE RESTRICT,

    FOREIGN KEY (barber_id, salon_id)
        REFERENCES barbers(id, salon_id)
        ON DELETE SET NULL (barber_id)
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reservation_id UUID REFERENCES reservations(id) ON DELETE CASCADE,

    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,

    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    reservation_id UUID NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,

    reviewer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reviewed_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reviewed_salon_id UUID REFERENCES salons(id) ON DELETE CASCADE,

    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (
        ((reviewed_user_id IS NOT NULL)::INT + (reviewed_salon_id IS NOT NULL)::INT) = 1
    )
);

CREATE INDEX IF NOT EXISTS ix_salons_owner_user_id ON salons(owner_user_id);
CREATE INDEX IF NOT EXISTS ix_salons_city ON salons(city);
CREATE INDEX IF NOT EXISTS ix_salons_active ON salons(is_active);

CREATE INDEX IF NOT EXISTS ix_salon_images_salon_id ON salon_images(salon_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_salon_images_one_main
    ON salon_images(salon_id)
    WHERE is_main = TRUE;

CREATE INDEX IF NOT EXISTS ix_barbers_salon_id ON barbers(salon_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_barbers_user_per_salon
    ON barbers(salon_id, user_id)
    WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_services_salon_id ON services(salon_id);
CREATE INDEX IF NOT EXISTS ix_services_active ON services(salon_id, is_active);

CREATE INDEX IF NOT EXISTS ix_working_hours_salon_day ON working_hours(salon_id, day_of_week);
CREATE INDEX IF NOT EXISTS ix_salon_breaks_salon_day ON salon_breaks(salon_id, day_of_week);

CREATE INDEX IF NOT EXISTS ix_reservations_customer_status ON reservations(customer_id, status);
CREATE INDEX IF NOT EXISTS ix_reservations_salon_time_status ON reservations(salon_id, start_time, end_time, status);
CREATE INDEX IF NOT EXISTS ix_reservations_service_id ON reservations(service_id);
CREATE INDEX IF NOT EXISTS ix_reservations_barber_id ON reservations(barber_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_reservations_one_active_per_customer
    ON reservations(customer_id)
    WHERE status IN ('Pending', 'Accepted');

CREATE INDEX IF NOT EXISTS ix_notifications_user_read ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_notifications_reservation_id ON notifications(reservation_id);

CREATE INDEX IF NOT EXISTS ix_reviews_reservation_id ON reviews(reservation_id);
CREATE INDEX IF NOT EXISTS ix_reviews_reviewed_user_id ON reviews(reviewed_user_id);
CREATE INDEX IF NOT EXISTS ix_reviews_reviewed_salon_id ON reviews(reviewed_salon_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_reviews_one_salon_review_per_reservation
    ON reviews(reservation_id, reviewer_user_id, reviewed_salon_id)
    WHERE reviewed_salon_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_reviews_one_user_review_per_reservation
    ON reviews(reservation_id, reviewer_user_id, reviewed_user_id)
    WHERE reviewed_user_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_salons_updated_at ON salons;
CREATE TRIGGER trg_salons_updated_at
BEFORE UPDATE ON salons
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_barbers_updated_at ON barbers;
CREATE TRIGGER trg_barbers_updated_at
BEFORE UPDATE ON barbers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_services_updated_at ON services;
CREATE TRIGGER trg_services_updated_at
BEFORE UPDATE ON services
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_reservations_updated_at ON reservations;
CREATE TRIGGER trg_reservations_updated_at
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE VIEW customer_reliability AS
SELECT
    u.id AS customer_id,
    u.full_name,
    u.email,
    COUNT(r.id) FILTER (WHERE r.status = 'Completed') AS completed_count,
    COUNT(r.id) FILTER (WHERE r.status = 'CancelledLate') AS cancelled_late_count,
    COUNT(r.id) FILTER (WHERE r.status = 'NoShow') AS no_show_count,
    CASE
        WHEN COUNT(r.id) FILTER (WHERE r.status IN ('Completed', 'CancelledLate', 'NoShow')) = 0
            THEN 'Novi korisnik'
        WHEN COUNT(r.id) FILTER (WHERE r.status = 'CancelledLate') = 0
             AND COUNT(r.id) FILTER (WHERE r.status = 'NoShow') = 0
            THEN 'Pouzdan korisnik'
        WHEN COUNT(r.id) FILTER (WHERE r.status = 'CancelledLate') >= 2
             OR COUNT(r.id) FILTER (WHERE r.status = 'NoShow') >= 1
            THEN 'Upozorenje: provjeri pouzdanost korisnika'
        ELSE 'Upozorenje: korisnik je jednom otkazao prekasno'
    END AS reliability_status
FROM users u
LEFT JOIN reservations r ON r.customer_id = u.id
WHERE u.role = 'Customer'
GROUP BY u.id, u.full_name, u.email;
