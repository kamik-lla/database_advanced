-- Создание базы данных
CREATE DATABASE db2026;

-- Единицы измерения
CREATE SEQUENCE seq_dim_ranges;
CREATE TABLE dim_ranges (
    id          BIGINT PRIMARY KEY DEFAULT nextval('seq_dim_ranges'),
    external_id BIGINT UNIQUE,
    name        TEXT NOT NULL,
    factor      FLOAT DEFAULT 1.0,
    date_add    TIMESTAMP DEFAULT now()
);

-- Категории товаров
CREATE SEQUENCE seq_dim_categories;
CREATE TABLE dim_categories (
    id                 BIGINT PRIMARY KEY DEFAULT nextval('seq_dim_categories'),
    external_id        BIGINT UNIQUE,
    name               TEXT NOT NULL,
    parent_external_id BIGINT,
    date_add           TIMESTAMP DEFAULT now()
);

-- Поставщики
CREATE SEQUENCE seq_dim_vendors;
CREATE TABLE dim_vendors (
    id                BIGINT PRIMARY KEY DEFAULT nextval('seq_dim_vendors'),
    external_id       BIGINT UNIQUE,
    name              TEXT NOT NULL,
    inn               TEXT,
    group_external_id INT,
    group_name        TEXT,
    date_add          TIMESTAMP DEFAULT now()
);

-- Продукция
CREATE SEQUENCE seq_dim_products;
CREATE TABLE dim_products (
    id                   BIGINT PRIMARY KEY DEFAULT nextval('seq_dim_products'),
    external_id          BIGINT UNIQUE,
    product_code         TEXT,
    name                 TEXT NOT NULL,
    category_external_id BIGINT,
    vendor_external_id   BIGINT,
    base_price           NUMERIC(18, 2) DEFAULT 0,
    date_add             TIMESTAMP DEFAULT now()
);

-- Персонал
CREATE SEQUENCE seq_dim_personnel;
CREATE TABLE dim_personnel (
    id          BIGINT PRIMARY KEY DEFAULT nextval('seq_dim_personnel'),
    external_id INT UNIQUE,
    login_id    TEXT UNIQUE,
    full_name   TEXT NOT NULL,
    role_access INT,
    date_add    TIMESTAMP DEFAULT now()
);

-- Склады
CREATE SEQUENCE seq_dim_stores;
CREATE TABLE dim_stores (
    id          BIGINT PRIMARY KEY DEFAULT nextval('seq_dim_stores'),
    external_id INT UNIQUE,
    name        TEXT NOT NULL,
    store_type  TEXT,
    date_add    TIMESTAMP DEFAULT now()
);

-- Справочник типов складских операций
CREATE TABLE dim_operation_types (
    id          INT PRIMARY KEY,
    description TEXT NOT NULL,
    factor      INT NOT NULL
);

INSERT INTO dim_operation_types (id, description, factor) VALUES
(1, 'Поступление', 1),
(2, 'Списание', -1),
(3, 'Инвентаризация', 1),
(4, 'Перемещение', 1),
(5, 'Возврат', 1)
ON CONFLICT (id) DO NOTHING;

-- Направление 1: Факты закупки продукции
CREATE SEQUENCE seq_fact_purchases;
CREATE TABLE fact_purchases (
    id                  BIGINT PRIMARY KEY DEFAULT nextval('seq_fact_purchases'),
    external_id         BIGINT UNIQUE,
    doc_number          TEXT,
    month_id            INT,
    product_external_id BIGINT,
    vendor_external_id  BIGINT,
    store_external_id   INT,
    quantity            NUMERIC(18, 4),
    purchase_price      NUMERIC(18, 2),
    total_amount        NUMERIC(18, 2),
    operation_date      TIMESTAMP,
    date_add            TIMESTAMP DEFAULT now()
);

-- Направление 2: Факты продажи товаров
CREATE SEQUENCE seq_fact_sales;
CREATE TABLE fact_sales (
    id                  BIGINT PRIMARY KEY DEFAULT nextval('seq_fact_sales'),
    receipt_number      NUMERIC(18, 0),
    trans_number        BIGINT,
    month_id            INT,
    product_code        TEXT,
    personnel_login     TEXT,
    store_external_id   INT,
    quantity            NUMERIC(18, 3),
    sale_price          NUMERIC(18, 2),
    sale_amount         NUMERIC(18, 2),
    sale_date           TIMESTAMP,
    date_add            TIMESTAMP DEFAULT now(),
    CONSTRAINT uq_fact_sales_receipt UNIQUE (receipt_number, trans_number)
);

-- Направление 3: Факты работы персонала (начисление премий и бонусов)
CREATE SEQUENCE seq_fact_personnel_bonuses;
CREATE TABLE fact_personnel_bonuses (
    id                 BIGINT PRIMARY KEY DEFAULT nextval('seq_fact_personnel_bonuses'),
    external_id        BIGINT UNIQUE,
    personnel_ext_id   INT,
    month_id           INT,
    bonus_amount       NUMERIC(18, 2),
    bonus_date         TIMESTAMP,
    date_add           TIMESTAMP DEFAULT now()
);

-- Направление 4: Факты движения остатков (партионный учет)
CREATE SEQUENCE seq_fact_inventory;
CREATE TABLE fact_inventory (
    id                  BIGINT PRIMARY KEY DEFAULT nextval('seq_fact_inventory'),
    external_id         BIGINT UNIQUE,
    operation_type_id   INT,
    month_id            INT,
    product_external_id BIGINT,
    store_external_id   INT,
    quantity_count      NUMERIC(18, 4),
    price_cost          NUMERIC(18, 2),
    movement_date       TIMESTAMP,
    date_add            TIMESTAMP DEFAULT now()
);

-- Создание индексов для быстрой выборки в OLAP
CREATE INDEX idx_purchases_month ON fact_purchases(month_id);
CREATE INDEX idx_sales_month ON fact_sales(month_id);
CREATE INDEX idx_bonuses_month ON fact_personnel_bonuses(month_id);
CREATE INDEX idx_inventory_month ON fact_inventory(month_id);