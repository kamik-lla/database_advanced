-- scriptDz7_2_validation_queries.sql
-- Запросы демонстрации: «Список параметров с ошибками» и «Лучший стрелок»

-- Подготовка тестовых демонстрационных пачек с корректными и некорректными данными
-- Привязка к существующим сотрудникам с обезличенными кодами (EMP_01, EMP_02, EMP_03)
DELETE FROM parameters WHERE batch_id BETWEEN 301 AND 312;
DELETE FROM batches WHERE id BETWEEN 301 AND 312;

INSERT INTO batches (id, code, employee_id, equipment_type_id, created_at) VALUES
    (301, 'BATCH_301', 1, 1, '2026-10-21 08:00:00'),
    (302, 'BATCH_302', 1, 2, '2026-10-21 08:30:00'),
    (303, 'BATCH_303', 1, 1, '2026-10-21 09:00:00'),
    (304, 'BATCH_304', 1, 2, '2026-10-21 09:30:00'),
    (305, 'BATCH_305', 2, 1, '2026-10-21 10:00:00'),
    (306, 'BATCH_306', 2, 2, '2026-10-21 10:30:00'),
    (307, 'BATCH_307', 2, 1, '2026-10-21 11:00:00'),
    (308, 'BATCH_308', 2, 2, '2026-10-21 11:30:00'),
    (309, 'BATCH_309', 3, 1, '2026-10-21 12:00:00'),
    (310, 'BATCH_310', 3, 1, '2026-10-21 12:30:00'),
    (311, 'BATCH_311', 3, 2, '2026-10-21 13:00:00'),
    (312, 'BATCH_312', 3, 2, '2026-10-21 13:30:00');

INSERT INTO parameters (id, code, batch_id, parameter_type_id, value) VALUES
    -- 301: Оператор 1 (ДМК, корректно)
    (3001, 'P_301_H',  301, 1, 100.0),
    (3002, 'P_301_T',  301, 2, 15.0),
    (3003, 'P_301_P',  301, 3, 750.0),
    (3004, 'P_301_WD', 301, 4, 10.0),
    (3005, 'P_301_WS', 301, 5, 5.0),

    -- 302: Оператор 1 (ВР, корректно)
    (3006, 'P_302_H',  302, 1, 120.0),
    (3007, 'P_302_T',  302, 2, 20.0),
    (3008, 'P_302_P',  302, 3, 755.0),
    (3009, 'P_302_WD', 302, 4, 15.0),
    (3010, 'P_302_BD', 302, 6, 45.0),

    -- 303: Оператор 1 (ДМК, корректно)
    (3011, 'P_303_H',  303, 1, 150.0),
    (3012, 'P_303_T',  303, 2, 25.0),
    (3013, 'P_303_P',  303, 3, 760.0),
    (3014, 'P_303_WD', 303, 4, 0.0),
    (3015, 'P_303_WS', 303, 5, 3.0),

    -- 304: Оператор 1 (ВР, корректно)
    (3016, 'P_304_H',  304, 1, 80.0),
    (3017, 'P_304_T',  304, 2, -10.0),
    (3018, 'P_304_P',  304, 3, 740.0),
    (3019, 'P_304_WD', 304, 4, 30.0),
    (3020, 'P_304_BD', 304, 6, 65.0),

    -- 305: Оператор 2 (ДМК, корректно)
    (3021, 'P_305_H',  305, 1, 90.0),
    (3022, 'P_305_T',  305, 2, 18.0),
    (3023, 'P_305_P',  305, 3, 748.0),
    (3024, 'P_305_WD', 305, 4, 5.0),
    (3025, 'P_305_WS', 305, 5, 4.0),

    -- 306: Оператор 2 (ВР, корректно)
    (3026, 'P_306_H',  306, 1, 110.0),
    (3027, 'P_306_T',  306, 2, 12.0),
    (3028, 'P_306_P',  306, 3, 752.0),
    (3029, 'P_306_WD', 306, 4, 20.0),
    (3030, 'P_306_BD', 306, 6, 40.0),

    -- 307: Оператор 2 (ДМК, ошибка температуры 65°C - вне диапазона)
    (3031, 'P_307_H',  307, 1, 100.0),
    (3032, 'P_307_T',  307, 2, 65.0),
    (3033, 'P_307_P',  307, 3, 750.0),
    (3034, 'P_307_WD', 307, 4, 10.0),
    (3035, 'P_307_WS', 307, 5, 5.0),

    -- 308: Оператор 2 (ВР, ошибка сноса пуль 180 м - вне диапазона)
    (3036, 'P_308_H',  308, 1, 100.0),
    (3037, 'P_308_T',  308, 2, 14.0),
    (3038, 'P_308_P',  308, 3, 750.0),
    (3039, 'P_308_WD', 308, 4, 15.0),
    (3040, 'P_308_BD', 308, 6, 180.0),

    -- 309: Оператор 3 (ДМК, ошибка давления 450 мм рт.ст.)
    (3041, 'P_309_H',  309, 1, 100.0),
    (3042, 'P_309_T',  309, 2, 15.0),
    (3043, 'P_309_P',  309, 3, 450.0),
    (3044, 'P_309_WD', 309, 4, 10.0),
    (3045, 'P_309_WS', 309, 5, 5.0),

    -- 310: Оператор 3 (ДМК, ошибка направления ветра 65)
    (3046, 'P_310_H',  310, 1, 100.0),
    (3047, 'P_310_T',  310, 2, 15.0),
    (3048, 'P_310_P',  310, 3, 750.0),
    (3049, 'P_310_WD', 310, 4, 65.0),
    (3050, 'P_310_WS', 310, 5, 5.0),

    -- 311: Оператор 3 (ВР, не заполнено давление)
    (3051, 'P_311_H',  311, 1, 100.0),
    (3052, 'P_311_T',  311, 2, 15.0),
    (3053, 'P_311_WD', 311, 4, 20.0),
    (3054, 'P_311_BD', 311, 6, 50.0),

    -- 312: Оператор 3 (ВР, комплексные ошибки: высота 6000м, температура -70°C, снос 200м)
    (3055, 'P_312_H',  312, 1, 6000.0),
    (3056, 'P_312_T',  312, 2, -70.0),
    (3057, 'P_312_P',  312, 3, 750.0),
    (3058, 'P_312_WD', 312, 4, 20.0),
    (3059, 'P_312_BD', 312, 6, 200.0);


-- ЗАПРОС 1: «Список параметров с ошибками»
-- Демонстрационная таблица по ТЗ Заказчика (History20261021)
-- Использует: CTE, горизонтальную проекцию (pivot) и ROW_NUMBER()
WITH batch_params AS (
    -- Проекция вертикальных параметров в горизонтальную строку (pivot в CTE)
    SELECT
        b.id AS batch_id,
        b.code AS batch_code,
        b.equipment_type_id,
        et.name AS equipment_type,
        MAX(CASE WHEN p.parameter_type_id = 1 THEN p.value END) AS height,
        MAX(CASE WHEN p.parameter_type_id = 2 THEN p.value END) AS temperature,
        MAX(CASE WHEN p.parameter_type_id = 3 THEN p.value END) AS pressure,
        MAX(CASE WHEN p.parameter_type_id = 4 THEN p.value END) AS wind_direction,
        MAX(CASE WHEN p.parameter_type_id = 5 THEN p.value END) AS wind_speed,
        MAX(CASE WHEN p.parameter_type_id = 6 THEN p.value END) AS bullet_drift
    FROM batches b
    JOIN equipment_types et ON et.id = b.equipment_type_id
    JOIN parameters p ON p.batch_id = b.id
    GROUP BY b.id, b.code, b.equipment_type_id, et.name
),
validated AS (
    -- Применение функции валидации параметров
    SELECT
        bp.*,
        validate_measurement_params(
            ROW(bp.height, bp.temperature, bp.pressure, bp.wind_direction, bp.wind_speed, bp.bullet_drift)::measurement_params,
            bp.equipment_type_id
        ) AS error_text
    FROM batch_params bp
)
SELECT
    ROW_NUMBER() OVER (ORDER BY batch_id) AS "№",
    equipment_type AS "Тип оборудования",
    height AS "Высота метеопоста",
    temperature AS "Температура",
    pressure AS "Давление",
    wind_direction AS "Направление ветра",
    wind_speed AS "Скорость ветра",
    bullet_drift AS "Дальность сноса пуль",
    CASE WHEN error_text IS NOT NULL THEN 'Да' ELSE 'Нет' END AS "Флаг: Есть ошибка",
    COALESCE(error_text, 'Ошибок не обнаружено') AS "Описание ошибки"
FROM validated
ORDER BY batch_id;


-- ЗАПРОС 2: «Лучший стрелок»
-- Список пользователей и количество допущенных ошибок
-- Использует: CTE, агрегацию, оконную функцию DENSE_RANK()
WITH batch_params AS (
    SELECT
        b.id AS batch_id,
        b.employee_id,
        b.equipment_type_id,
        validate_measurement_params(
            ROW(
                MAX(CASE WHEN p.parameter_type_id = 1 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 2 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 3 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 4 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 5 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 6 THEN p.value END)
            )::measurement_params,
            b.equipment_type_id
        ) AS error_text
    FROM batches b
    JOIN parameters p ON p.batch_id = b.id
    GROUP BY b.id, b.employee_id, b.equipment_type_id
),
operator_stats AS (
    SELECT
        e.id AS employee_id,
        e.code AS employee_code,
        pos.name AS position_name,
        COUNT(bp.batch_id) AS total_batches,
        COUNT(CASE WHEN bp.error_text IS NOT NULL THEN 1 END) AS error_batches,
        COUNT(CASE WHEN bp.error_text IS NULL THEN 1 END) AS correct_batches,
        SUM(
            CASE 
                WHEN bp.error_text IS NULL THEN 0
                ELSE CARDINALITY(STRING_TO_ARRAY(bp.error_text, '; '))
            END
        ) AS total_errors
    FROM employees e
    LEFT JOIN positions pos ON pos.id = e.position_id
    JOIN batch_params bp ON bp.employee_id = e.id
    GROUP BY e.id, e.code, pos.name
)
SELECT
    DENSE_RANK() OVER (ORDER BY total_errors ASC, correct_batches DESC) AS "№",
    employee_code AS "Код сотрудника",
    position_name AS "Должность",
    total_batches AS "Всего пачек",
    error_batches AS "Пачек с ошибками",
    total_errors AS "Количество ошибок",
    CASE
        WHEN total_errors = 0 THEN 'Отлично'
        WHEN total_errors <= 2 THEN 'Хорошо'
        WHEN total_errors <= 4 THEN 'Удовлетворительно'
        ELSE 'Неудовлетворительно'
    END AS "Оценка",
    ROUND(correct_batches::NUMERIC / NULLIF(total_batches, 0) * 100.0, 1) || '%' AS "Точность ввода"
FROM operator_stats
ORDER BY "№";
