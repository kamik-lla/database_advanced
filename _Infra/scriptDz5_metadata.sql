-- ДЗ 5: Вывод метаданных базы данных (таблицы, счетчики, ограничения)
SELECT 
    ROW_NUMBER() OVER (ORDER BY "Тип" DESC, "Наименование" ASC) AS "№",
    "Наименование",
    "Тип"
FROM (
    -- 1. Таблицы
    SELECT 
        table_name AS "Наименование",
        'Таблица' AS "Тип"
    FROM information_schema.tables
    WHERE table_catalog = current_database()
      AND table_schema = 'public'
      AND table_type = 'BASE TABLE'
    
    UNION ALL
    
    -- 2. Счетчики (последовательности)
    SELECT 
        sequence_name AS "Наименование",
        'Счетчик' AS "Тип"
    FROM information_schema.sequences
    WHERE sequence_catalog = current_database()
      AND sequence_schema = 'public'
      
    UNION ALL
    
    -- 3. Ограничения (первичные, внешние ключи, уникальность, проверки)
    SELECT 
        constraint_name AS "Наименование",
        'Ограничение' AS "Тип"
    FROM information_schema.table_constraints
    WHERE table_catalog = current_database()
      AND table_schema = 'public'
      AND constraint_name NOT LIKE '%_not_null'
) all_objects
ORDER BY "№";
