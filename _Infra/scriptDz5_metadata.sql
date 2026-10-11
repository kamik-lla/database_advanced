-- Метаданные таблиц
SELECT 
    ROW_NUMBER() OVER (ORDER BY table_name) AS "№",
    table_name AS "Наименование",
    CASE table_type
        WHEN 'BASE TABLE' THEN 'Таблица'
        WHEN 'VIEW' THEN 'Представление'
        ELSE table_type
    END AS "Тип"
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
