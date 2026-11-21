-- 1. Процедура для порционной вставки/обновления товаров
CREATE OR REPLACE PROCEDURE sp_upsert_dim_product(
    p_external_id BIGINT,
    p_code TEXT,
    p_name TEXT,
    p_category_id BIGINT,
    p_vendor_id BIGINT,
    p_price NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO dim_products (external_id, product_code, name, category_external_id, vendor_external_id, base_price)
    VALUES (p_external_id, p_code, p_name, p_category_id, p_vendor_id, p_price)
    ON CONFLICT (external_id) DO UPDATE SET
        name = EXCLUDED.name,
        category_external_id = EXCLUDED.category_external_id,
        vendor_external_id = EXCLUDED.vendor_external_id,
        base_price = EXCLUDED.base_price;
END;
$$;

-- 2. Процедура для порционной вставки/обновления поставщиков
CREATE OR REPLACE PROCEDURE sp_upsert_dim_vendor(
    p_external_id BIGINT,
    p_name TEXT,
    p_inn TEXT,
    p_group_id INT,
    p_group_name TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO dim_vendors (external_id, name, inn, group_external_id, group_name)
    VALUES (p_external_id, p_name, p_inn, p_group_id, p_group_name)
    ON CONFLICT (external_id) DO UPDATE SET
        name = EXCLUDED.name,
        inn = EXCLUDED.inn,
        group_name = EXCLUDED.group_name;
END;
$$;

-- 3. Процедура для порционной вставки фактов закупки
CREATE OR REPLACE PROCEDURE sp_upsert_fact_purchase(
    p_external_id BIGINT,
    p_doc_number TEXT,
    p_month_id INT,
    p_product_id BIGINT,
    p_vendor_id BIGINT,
    p_store_id INT,
    p_qty NUMERIC,
    p_price NUMERIC,
    p_amount NUMERIC,
    p_date TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO fact_purchases (
        external_id, doc_number, month_id, product_external_id, 
        vendor_external_id, store_external_id, quantity, purchase_price, total_amount, operation_date
    )
    VALUES (
        p_external_id, p_doc_number, p_month_id, p_product_id, 
        p_vendor_id, p_store_id, p_qty, p_price, p_amount, p_date
    )
    ON CONFLICT (external_id) DO UPDATE SET
        quantity = EXCLUDED.quantity,
        purchase_price = EXCLUDED.purchase_price,
        total_amount = EXCLUDED.total_amount;
END;
$$;