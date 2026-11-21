USE Front;


-- 1. ВЫБОРКА ИЗМЕРЕНИЙ (DIMENSIONS)

-- Единицы измерения:
SELECT id, sizeid AS name, portionrate AS factor 
FROM [size];

-- Категории:
SELECT id, description AS name,
       CASE WHEN COALESCE(ParentID, 0) = 0 THEN NULL ELSE ParentID END AS parent_id
FROM category;

-- Поставщики:
SELECT t1.id, 
       COALESCE(t1.lastname, t1.clientid, 'Без названия') AS name, 
       t1.clientgroup AS group_id, 
       t2.description AS group_name,
       COALESCE(t1.INN, '') AS inn
FROM vendors t1
LEFT JOIN vendorgroup t2 ON t1.clientgroup = t2.vendorgroupid;

-- Товары:
SELECT id, productid AS product_code, description AS name, 
       subcategoryid AS category_id, vendorid, COALESCE(price1, 0) AS price
FROM product;

-- Персонал:
SELECT personid AS external_id, loginid, 
       LTRIM(RTRIM(COALESCE(lastname, '') + ' ' + COALESCE(firstname, ''))) AS full_name,
       securityaccess AS role_access
FROM personnel;

-- Склады и залы:
SELECT storeid AS external_id, description AS name, 'Склад/Зал' AS store_type
FROM stores;


-- 2. ВЫБОРКА ФАКТОВ ПО 4 НАПРАВЛЕНИЯМ (С ГЕНЕРАЦИЕЙ INSERT-КУСОЧКОВ)


-- Направление 1: Закупки продукции
SELECT TOP 100 
    'INSERT INTO fact_purchases(external_id, doc_number, month_id, product_external_id, vendor_external_id, store_external_id, quantity, purchase_price, total_amount, operation_date) VALUES ('
    + CAST(ID AS VARCHAR(50)) + ','''
    + CAST(DocumentID AS VARCHAR(50)) + ''','
    + CONVERT(VARCHAR(6), DateAdd, 112) + ','
    + CAST(ProductID AS VARCHAR(50)) + ','
    + CAST(VendorID AS VARCHAR(50)) + ','
    + CAST(StorageID AS VARCHAR(50)) + ','
    + CAST(Count AS VARCHAR(50)) + ','
    + CAST(Price AS VARCHAR(50)) + ','
    + CAST(Amount AS VARCHAR(50)) + ','''
    + CONVERT(VARCHAR(19), DateAdd, 120) + ''') ON CONFLICT (external_id) DO UPDATE SET quantity = EXCLUDED.quantity, total_amount = EXCLUDED.total_amount;' AS [sql_purchases]
FROM bm_StorageOperations
WHERE OperationID = 1;

-- Направление 2: Продажи товара
SELECT TOP 100
    'INSERT INTO fact_sales(receipt_number, trans_number, month_id, product_code, personnel_login, store_external_id, quantity, sale_price, sale_amount, sale_date) VALUES ('
    + CAST(receiptn AS VARCHAR(50)) + ','
    + CAST(transnumber AS VARCHAR(50)) + ','
    + CONVERT(VARCHAR(6), dater, 112) + ','''
    + REPLACE(CAST(id AS VARCHAR(50)), '''', '''''') + ''','''
    + REPLACE(CAST(loginid AS VARCHAR(50)), '''', '''''') + ''','
    + CAST(storeid AS VARCHAR(50)) + ','
    + CAST(quantity AS VARCHAR(50)) + ','
    + CAST(price AS VARCHAR(50)) + ','
    + CAST(amount AS VARCHAR(50)) + ','''
    + CONVERT(VARCHAR(19), dater, 120) + ''') ON CONFLICT (receipt_number, trans_number) DO NOTHING;' AS [sql_sales]
FROM journal
WHERE grouptranstype = 1;

-- Направление 3: Работа персонала (бонусы)
SELECT TOP 100
    'INSERT INTO fact_personnel_bonuses(external_id, personnel_ext_id, month_id, bonus_amount, bonus_date) VALUES ('
    + CAST(ID AS VARCHAR(50)) + ','
    + CAST(PersonID AS VARCHAR(50)) + ','
    + CONVERT(VARCHAR(6), DateAdd, 112) + ','
    + CAST(Bonus AS VARCHAR(50)) + ','''
    + CONVERT(VARCHAR(19), DateAdd, 120) + ''') ON CONFLICT (external_id) DO UPDATE SET bonus_amount = EXCLUDED.bonus_amount;' AS [sql_bonuses]
FROM bm_BonusHistory;

-- Направление 4: Остатки (движения склада)
SELECT TOP 100
    'INSERT INTO fact_inventory(external_id, operation_type_id, month_id, product_external_id, store_external_id, quantity_count, price_cost, movement_date) VALUES ('
    + CAST(ID AS VARCHAR(50)) + ','
    + CAST(OperationID AS VARCHAR(50)) + ','
    + CONVERT(VARCHAR(6), DateAdd, 112) + ','
    + CAST(ProductID AS VARCHAR(50)) + ','
    + CAST(StorageID AS VARCHAR(50)) + ','
    + CAST(Count AS VARCHAR(50)) + ','
    + CAST(PriceCost AS VARCHAR(50)) + ','''
    + CONVERT(VARCHAR(19), DateAdd, 120) + ''') ON CONFLICT (external_id) DO NOTHING;' AS [sql_inventory]
FROM bm_StorageOperations;