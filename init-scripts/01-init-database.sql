-- ============================================================================
-- DATA1500 - Oblig 1: Arbeidskrav I våren 2026
-- Initialiserings-skript for PostgreSQL
-- ============================================================================

-- Rydd opp (idempotent)
DROP VIEW IF EXISTS v_kunde_utleier;
DROP TABLE IF EXISTS rentals CASCADE;
DROP TABLE IF EXISTS bikes CASCADE;
DROP TABLE IF EXISTS locks CASCADE;
DROP TABLE IF EXISTS stations CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- Opprett grunnleggende tabeller
CREATE TABLE customer (
    customer_id    SERIAL PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    phone          VARCHAR(16)  NOT NULL UNIQUE,
    email          VARCHAR(255) NOT NULL UNIQUE,
    db_username    VARCHAR(63) UNIQUE,
    registered_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (phone ~ '^\+?[0-9]{8,15}$'),
    CHECK (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$')
);

CREATE TABLE stations (
    station_id  SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    address     VARCHAR(200) NOT NULL,
    capacity    INTEGER NOT NULL CHECK (capacity > 0)
);

CREATE TABLE locks (
    lock_id     SERIAL PRIMARY KEY,
    station_id  INTEGER NOT NULL REFERENCES stations(station_id) ON DELETE CASCADE,
    lock_number INTEGER NOT NULL CHECK (lock_number > 0),
    status      VARCHAR(20) NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'broken', 'reserved')),
    UNIQUE (station_id, lock_number)
);

CREATE TABLE bikes (
    bike_id          SERIAL PRIMARY KEY,
    model            VARCHAR(80) NOT NULL,
    purchase_date    DATE NOT NULL,
    in_service_since DATE NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'maintenance', 'retired')),
    lock_id          INTEGER REFERENCES locks(lock_id) ON DELETE SET NULL,
    CHECK (in_service_since >= purchase_date)
);

CREATE TABLE rentals (
    rental_id        SERIAL PRIMARY KEY,
    customer_id      INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    bike_id          INTEGER NOT NULL REFERENCES bikes(bike_id) ON DELETE RESTRICT,
    start_station_id INTEGER NOT NULL REFERENCES stations(station_id) ON DELETE RESTRICT,
    start_lock_id    INTEGER REFERENCES locks(lock_id) ON DELETE SET NULL,
    end_station_id   INTEGER REFERENCES stations(station_id) ON DELETE RESTRICT,
    start_time       TIMESTAMPTZ NOT NULL,
    end_time         TIMESTAMPTZ,
    amount_nok       NUMERIC(10,2) CHECK (amount_nok >= 0),
    CHECK (end_time IS NULL OR end_time >= start_time),
    CHECK ((end_time IS NULL) = (end_station_id IS NULL)),
    CHECK (end_time IS NULL OR amount_nok IS NOT NULL)
);

-- Sett inn testdata
INSERT INTO stations (name, address, capacity) VALUES
    ('Sentrum Stasjon', 'Karl Johans gate 1, Oslo', 20),
    ('Universitetet Stasjon', 'Blindern, Oslo', 20),
    ('Grünerløkka Stasjon', 'Thorvald Meyers gate 10, Oslo', 20),
    ('Aker Brygge Stasjon', 'Stranden 1, Oslo', 20),
    ('Majorstuen Stasjon', 'Bogstadveien 50, Oslo', 20);

INSERT INTO locks (station_id, lock_number)
SELECT ((g - 1) / 20) + 1 AS station_id,
       ((g - 1) % 20) + 1 AS lock_number
FROM generate_series(1, 100) AS g;

INSERT INTO bikes (model, purchase_date, in_service_since, status, lock_id)
SELECT
    CASE (g % 4)
        WHEN 0 THEN 'City Bike Pro'
        WHEN 1 THEN 'Urban Cruiser'
        WHEN 2 THEN 'EcoBike 3000'
        ELSE 'City Bike Lite'
    END AS model,
    DATE '2023-01-10' + (g % 400) AS purchase_date,
    DATE '2023-01-10' + (g % 400) + 7 AS in_service_since,
    'active' AS status,
    CASE WHEN g IN (11, 21, 31, 41, 51) THEN NULL ELSE g END AS lock_id
FROM generate_series(1, 100) AS g;

INSERT INTO customers (first_name, last_name, phone, email, db_username, registered_at) VALUES
    ('Ole', 'Hansen', '+4791234567', 'ole.hansen@example.com', 'kunde_1', '2024-05-01 10:00:00+02'),
    ('Kari', 'Olsen', '+4792345678', 'kari.olsen@example.com', NULL, '2024-05-03 12:00:00+02'),
    ('Per', 'Andersen', '+4793456789', 'per.andersen@example.com', NULL, '2024-05-05 09:30:00+02'),
    ('Lise', 'Johansen', '+4794567890', 'lise.johansen@example.com', NULL, '2024-05-06 14:15:00+02'),
    ('Anna', 'Nilsen', '+4796789012', 'anna.nilsen@example.com', NULL, '2024-05-08 08:45:00+02');

INSERT INTO rentals (
    customer_id,
    bike_id,
    start_station_id,
    start_lock_id,
    end_station_id,
    start_time,
    end_time,
    amount_nok
)
SELECT
    (g % 5) + 1 AS customer_id,
    (g % 100) + 1 AS bike_id,
    (g % 5) + 1 AS start_station_id,
    (g % 100) + 1 AS start_lock_id,
    CASE WHEN g % 10 = 0 THEN NULL ELSE ((g + 1) % 5) + 1 END AS end_station_id,
    TIMESTAMPTZ '2024-06-01 08:00:00+02' + (g || ' days')::interval AS start_time,
    CASE
        WHEN g % 10 = 0 THEN NULL
        ELSE TIMESTAMPTZ '2024-06-01 08:00:00+02' + (g || ' days')::interval + (45 + (g % 60)) * INTERVAL '1 minute'
    END AS end_time,
    CASE WHEN g % 10 = 0 THEN NULL ELSE 29.00 + (g % 20) END AS amount_nok
FROM generate_series(1, 50) AS g;

-- Indekser for typiske oppslag
CREATE INDEX idx_rentals_customer ON rentals(customer_id);
CREATE INDEX idx_rentals_bike ON rentals(bike_id);
CREATE INDEX idx_rentals_open ON rentals(end_time);

-- Begrenset visning for kunder
CREATE VIEW v_kunde_utleier AS
SELECT r.rental_id, r.bike_id, r.start_station_id, r.end_station_id,
       r.start_time, r.end_time, r.amount_nok
FROM rentals r
JOIN customers c ON c.customer_id = r.customer_id
WHERE c.db_username = current_user;

-- DBA setninger (rolle: kunde, bruker: kunde_1)
DROP ROLE IF EXISTS kunde_1;
DROP ROLE IF EXISTS kunde;

CREATE ROLE kunde;
CREATE USER kunde_1 WITH PASSWORD 'kunde123';
GRANT kunde TO kunde_1;

REVOKE ALL ON customers, rentals FROM PUBLIC;
GRANT SELECT ON stations, locks, bikes TO kunde;
GRANT SELECT ON v_kunde_utleier TO kunde;

-- Vis at initialisering er fullført
SELECT 'Database initialisert!' as status;
