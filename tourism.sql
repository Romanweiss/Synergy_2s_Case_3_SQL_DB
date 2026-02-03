-- ============================================
-- БД "Туризм" (PostgreSQL)
-- 4 справочника + 1 таблица переменной информации
-- ============================================

-- (опционально) создаём отдельную схему, чтобы всё было аккуратно
CREATE SCHEMA IF NOT EXISTS tourism;
SET search_path TO tourism;

-- =========================
-- 1) Справочник: Клиенты
-- =========================
CREATE TABLE IF NOT EXISTS clients (
    client_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name      TEXT NOT NULL,
    phone          TEXT NOT NULL UNIQUE,
    email          TEXT UNIQUE,
    passport_no    TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================
-- 2) Справочник: Туры
-- =========================
CREATE TABLE IF NOT EXISTS tours (
    tour_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tour_name      TEXT NOT NULL,
    country        TEXT NOT NULL,
    city           TEXT,
    nights         INTEGER NOT NULL CHECK (nights > 0),
    base_price     NUMERIC(12,2) NOT NULL CHECK (base_price >= 0),
    is_active      BOOLEAN NOT NULL DEFAULT TRUE
);

-- =========================
-- 3) Справочник: Услуги
-- =========================
CREATE TABLE IF NOT EXISTS services (
    service_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_name   TEXT NOT NULL UNIQUE,
    price          NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    description    TEXT
);

-- =========================
-- 4) Справочник: Менеджеры
-- =========================
CREATE TABLE IF NOT EXISTS managers (
    manager_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name      TEXT NOT NULL,
    email          TEXT UNIQUE,
    phone          TEXT UNIQUE
);

-- =========================
-- 5) Переменная таблица: Заказы
-- =========================
CREATE TABLE IF NOT EXISTS orders (
    order_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    client_id      BIGINT NOT NULL,
    tour_id        BIGINT NOT NULL,
    service_id     BIGINT,        -- доп. услуга может отсутствовать
    manager_id     BIGINT,        -- менеджер может отсутствовать (например, онлайн-заказ)

    start_date     DATE NOT NULL,
    persons        INTEGER NOT NULL CHECK (persons > 0),

    -- итоговая стоимость заказа (можно хранить как фикс на момент покупки)
    total_price    NUMERIC(12,2) NOT NULL CHECK (total_price >= 0),

    status         TEXT NOT NULL DEFAULT 'new'
                  CHECK (status IN ('new', 'confirmed', 'paid', 'cancelled', 'completed')),

    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_orders_client
        FOREIGN KEY (client_id) REFERENCES clients(client_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_orders_tour
        FOREIGN KEY (tour_id) REFERENCES tours(tour_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_orders_service
        FOREIGN KEY (service_id) REFERENCES services(service_id)
        ON UPDATE CASCADE ON DELETE SET NULL,

    CONSTRAINT fk_orders_manager
        FOREIGN KEY (manager_id) REFERENCES managers(manager_id)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- Индексы для ускорения типовых запросов
CREATE INDEX IF NOT EXISTS idx_orders_client_id  ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_tour_id    ON orders(tour_id);
CREATE INDEX IF NOT EXISTS idx_orders_status     ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_start_date ON orders(start_date);

-- ============================================
-- (опционально) тестовые данные, чтобы показать работу
-- ============================================
INSERT INTO clients (full_name, phone, email, passport_no)
VALUES
('Иванов Иван Иванович', '+79990000001', 'ivanov@mail.ru', '1234 567890'),
('Петров Пётр Петрович', '+79990000002', 'petrov@mail.ru', '2345 678901')
ON CONFLICT DO NOTHING;

INSERT INTO tours (tour_name, country, city, nights, base_price, is_active)
VALUES
('Тур: Римские каникулы', 'Италия', 'Рим', 7, 85000.00, TRUE),
('Тур: Море и солнце', 'Турция', 'Анталья', 10, 95000.00, TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO services (service_name, price, description)
VALUES
('Страховка', 2500.00, 'Медицинская страховка на период поездки'),
('Трансфер', 1800.00, 'Трансфер аэропорт–отель–аэропорт')
ON CONFLICT DO NOTHING;

INSERT INTO managers (full_name, email, phone)
VALUES
('Сидорова Анна', 'sidorova@agency.ru', '+79990000003')
ON CONFLICT DO NOTHING;

-- Пример заказа (итоговую цену считаем вручную для примера)
INSERT INTO orders (client_id, tour_id, service_id, manager_id, start_date, persons, total_price, status)
SELECT
    c.client_id,
    t.tour_id,
    s.service_id,
    m.manager_id,
    DATE '2026-03-10',
    2,
    (t.base_price * 2) + s.price,
    'confirmed'
FROM clients c, tours t, services s, managers m
WHERE c.phone = '+79990000001'
  AND t.tour_name = 'Тур: Римские каникулы'
  AND s.service_name = 'Страховка'
  AND m.full_name = 'Сидорова Анна'
ON CONFLICT DO NOTHING;
