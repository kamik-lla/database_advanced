-- ДЕМОНСТРАЦИОННЫЕ ДАННЫЕ И SQL-ЗАПРОСЫ

DELETE FROM parameters WHERE batch_id BETWEEN 301 AND 315;
DELETE FROM batches WHERE id BETWEEN 301 AND 315;

INSERT INTO batches (id, code, employee_id, equipment_type_id, created_at) VALUES
    (301, 'BATCH-101', 1, 1, TIMESTAMP '2026-10-21 08:00:00'),
    (302, 'BATCH-102', 1, 2, TIMESTAMP '2026-10-21 08:30:00'),
    (303, 'BATCH-103', 1, 1, TIMESTAMP '2026-10-21 09:00:00'),
    (304, 'BATCH-104', 1, 2, TIMESTAMP '2026-10-21 09:30:00'),

    (305, 'BATCH-105', 2, 1, TIMESTAMP '2026-10-21 10:00:00'),
    (306, 'BATCH-106', 2, 2, TIMESTAMP '2026-10-21 10:30:00'),
    (307, 'BATCH-107', 2, 1, TIMESTAMP '2026-10-21 11:00:00'),
    (308, 'BATCH-108', 2, 2, TIMESTAMP '2026-10-21 11:30:00'),

    (309, 'BATCH-109', 3, 1, TIMESTAMP '2026-10-21 12:00:00'),
    (310, 'BATCH-110', 3, 1, TIMESTAMP '2026-10-21 12:30:00'),
    (311, 'BATCH-111', 3, 1, TIMESTAMP '2026-10-21 13:00:00'),
    (312, 'BATCH-112', 3, 1, TIMESTAMP '2026-10-21 13:30:00'),
    (313, 'BATCH-113', 3, 1, TIMESTAMP '2026-10-21 14:00:00'),
    (314, 'BATCH-114', 3, 2, TIMESTAMP '2026-10-21 14:30:00'),
    (315, 'BATCH-115', 3, 2, TIMESTAMP '2026-10-21 15:00:00');

INSERT INTO parameters (id, code, batch_id, parameter_type_id, value) VALUES
    -- 301: Воловиков (ДМК, корректно)
    (3001, 'P_301_H',  301, 1, 100.0),
    (3002, 'P_301_T',  301, 2, 15.0),
    (3003, 'P_301_P',  301, 3, 750.0),
    (3004, 'P_301_WD', 301, 4, 0.0),
    (3005, 'P_301_WS', 301, 5, 0.0),

    -- 302: Воловиков (ВР, корректно)
    (3006, 'P_302_H',  302, 1, 100.0),
    (3007, 'P_302_T',  302, 2, 15.0),
    (3008, 'P_302_P',  302, 3, 750.0),
    (3009, 'P_302_WD', 302, 4, 0.0),
    (3010, 'P_302_BD', 302, 6, 0.0),

    -- 303: Воловиков (ДМК, корректно - пример 2 ТЗ)
    (3011, 'P_303_H',  303, 1, 100.0),
    (3012, 'P_303_T',  303, 2, 25.0),
    (3013, 'P_303_P',  303, 3, 765.0),
    (3014, 'P_303_WD', 303, 4, 15.0),
    (3015, 'P_303_WS', 303, 5, 6.0),

    -- 304: Воловиков (ВР, корректно)
    (3016, 'P_304_H',  304, 1, 200.0),
    (3017, 'P_304_T',  304, 2, -10.0),
    (3018, 'P_304_P',  304, 3, 740.0),
    (3019, 'P_304_WD', 304, 4, 30.0),
    (3020, 'P_304_BD', 304, 6, 65.0),

    -- 305: Иванов (ДМК, корректно)
    (3021, 'P_305_H',  305, 1, 150.0),
    (3022, 'P_305_T',  305, 2, 18.0),
    (3023, 'P_305_P',  305, 3, 755.0),
    (3024, 'P_305_WD', 305, 4, 10.0),
    (3025, 'P_305_WS', 305, 5, 4.0),

    -- 306: Иванов (ВР, корректно)
    (3026, 'P_306_H',  306, 1, 180.0),
    (3027, 'P_306_T',  306, 2, 8.5),
    (3028, 'P_306_P',  306, 3, 748.0),
    (3029, 'P_306_WD', 306, 4, 25.0),
    (3030, 'P_306_BD', 306, 6, 45.0),

    -- 307: Иванов (ДМК, ошибка температуры 65.0)
    (3031, 'P_307_H',  307, 1, 100.0),
    (3032, 'P_307_T',  307, 2, 65.0),
    (3033, 'P_307_P',  307, 3, 750.0),
    (3034, 'P_307_WD', 307, 4, 20.0),
    (3035, 'P_307_WS', 307, 5, 5.0),

    -- 308: Иванов (ВР, ошибка сноса пуль 180)
    (3036, 'P_308_H',  308, 1, 100.0),
    (3037, 'P_308_T',  308, 2, 12.0),
    (3038, 'P_308_P',  308, 3, 752.0),
    (3039, 'P_308_WD', 308, 4, 15.0),
    (3040, 'P_308_BD', 308, 6, 180.0),

    -- 309: Сидоров (ДМК, корректно)
    (3041, 'P_309_H',  309, 1, 80.0),
    (3042, 'P_309_T',  309, 2, 20.0),
    (3043, 'P_309_P',  309, 3, 750.0),
    (3044, 'P_309_WD', 309, 4, 0.0),
    (3045, 'P_309_WS', 309, 5, 2.0),

    -- 310: Сидоров (ДМК, ошибка давления 450)
    (3046, 'P_310_H',  310, 1, 100.0),
    (3047, 'P_310_T',  310, 2, 15.0),
    (3048, 'P_310_P',  310, 3, 450.0),
    (3049, 'P_310_WD', 310, 4, 20.0),
    (3050, 'P_310_WS', 310, 5, 5.0),

    -- 311: Сидоров (ДМК, ошибка направления ветра 65)
    (3051, 'P_311_H',  311, 1, 100.0),
    (3052, 'P_311_T',  311, 2, 15.0),
    (3053, 'P_311_P',  311, 3, 750.0),
    (3054, 'P_311_WD', 311, 4, 65.0),
    (3055, 'P_311_WS', 311, 5, 5.0),

    -- 312: Сидоров (ДМК, ошибка скорости ветра 22)
    (3056, 'P_312_H',  312, 1, 100.0),
    (3057, 'P_312_T',  312, 2, 15.0),
    (3058, 'P_312_P',  312, 3, 750.0),
    (3059, 'P_312_WD', 312, 4, 20.0),
    (3060, 'P_312_WS', 312, 5, 22.0),

    -- 313: Сидоров (ДМК, несовместимый снос пуль)
    (3061, 'P_313_H',  313, 1, 100.0),
    (3062, 'P_313_T',  313, 2, 15.0),
    (3063, 'P_313_P',  313, 3, 750.0),
    (3064, 'P_313_WD', 313, 4, 20.0),
    (3065, 'P_313_WS', 313, 5, 5.0),
    (3066, 'P_313_BD', 313, 6, 50.0),

    -- 314: Сидоров (ВР, не указано давление)
    (3067, 'P_314_H',  314, 1, 100.0),
    (3068, 'P_314_T',  314, 2, 15.0),
    (3069, 'P_314_WD', 314, 4, 20.0),
    (3070, 'P_314_BD', 314, 6, 50.0),

    -- 315: Сидоров (ВР, комплексная ошибка)
    (3071, 'P_315_H',  315, 1, 6000.0),
    (3072, 'P_315_T',  315, 2, -60.0),
    (3073, 'P_315_P',  315, 3, 400.0),
    (3074, 'P_315_WD', 315, 4, 70.0),
    (3075, 'P_315_BD', 315, 6, 200.0);


-- ЗАПРОС 1: «Список параметров с ошибками»
WITH raw_batch_params AS (
    -- Агрегация вертикальных параметров в горизонтальную проекцию
    SELECT
        b.id AS batch_id,
        b.code AS batch_code,
        et.code AS eq_code,
        COALESCE(et.name, 'Не указан') AS eq_name,
        MAX(CASE WHEN pt.code = 'HEIGHT' THEN p.value END) AS height,
        MAX(CASE WHEN pt.code = 'TEMPERATURE' THEN p.value END) AS temperature,
        MAX(CASE WHEN pt.code = 'PRESSURE' THEN p.value END) AS pressure,
        MAX(CASE WHEN pt.code IN ('WIND_DIR', 'WIND_DIRECTION') THEN p.value END) AS wind_direction,
        MAX(CASE WHEN pt.code = 'WIND_SPEED' THEN p.value END) AS wind_speed,
        MAX(CASE WHEN pt.code = 'BULLET_DRIFT' THEN p.value END) AS bullet_drift
    FROM batches b
    LEFT JOIN equipment_types et ON b.equipment_type_id = et.id
    LEFT JOIN parameters p ON p.batch_id = b.id
    LEFT JOIN parameter_types pt ON p.parameter_type_id = pt.id
    WHERE b.id BETWEEN 301 AND 315
    GROUP BY b.id, b.code, et.code, et.name
),
validated_batches AS (
    -- Валидация через функцию validate_measurement_params с типом measurement_params
    SELECT
        batch_id,
        batch_code,
        eq_name AS equipment_type,
        height,
        temperature,
        pressure,
        wind_direction,
        wind_speed,
        bullet_drift,
        validate_measurement_params(
            ROW(eq_code, height, temperature, pressure, wind_direction, wind_speed, bullet_drift)::measurement_params
        ) AS error_text
    FROM raw_batch_params
)
SELECT
    batch_code AS "№",
    equipment_type AS "Тип оборудования",
    height AS "Высота метеопоста",
    temperature AS "Температура",
    pressure AS "Давление",
    wind_direction AS "Направление ветра",
    wind_speed AS "Скорость ветра",
    bullet_drift AS "Дальность сноса пуль",
    CASE 
        WHEN error_text IS NOT NULL THEN 'Да' 
        ELSE 'Нет' 
    END AS "Флаг: Есть ошибка",
    COALESCE(error_text, 'Ошибок не обнаружено') AS "Описание ошибки"
FROM validated_batches
ORDER BY batch_id;


-- ЗАПРОС 2: «Лучший стрелок»
WITH batch_validation_stat AS (
    -- Сбор пачек пользователей и определение ошибок
    SELECT
        b.id AS batch_id,
        b.employee_id,
        validate_measurement_params(
            ROW(
                et.code,
                MAX(CASE WHEN pt.code = 'HEIGHT' THEN p.value END),
                MAX(CASE WHEN pt.code = 'TEMPERATURE' THEN p.value END),
                MAX(CASE WHEN pt.code = 'PRESSURE' THEN p.value END),
                MAX(CASE WHEN pt.code IN ('WIND_DIR', 'WIND_DIRECTION') THEN p.value END),
                MAX(CASE WHEN pt.code = 'WIND_SPEED' THEN p.value END),
                MAX(CASE WHEN pt.code = 'BULLET_DRIFT' THEN p.value END)
            )::measurement_params
        ) AS errors
    FROM batches b
    LEFT JOIN equipment_types et ON b.equipment_type_id = et.id
    LEFT JOIN parameters p ON p.batch_id = b.id
    LEFT JOIN parameter_types pt ON p.parameter_type_id = pt.id
    WHERE b.id BETWEEN 301 AND 315
    GROUP BY b.id, b.employee_id, et.code
),
user_error_aggregation AS (
    -- Группировка по сотрудникам и подсчет допущенных ошибок
    SELECT
        e.id AS employee_id,
        e.name AS employee_name,
        COUNT(bvs.batch_id) AS total_batches,
        COUNT(CASE WHEN bvs.errors IS NOT NULL THEN 1 END) AS error_batches_count,
        COUNT(CASE WHEN bvs.errors IS NULL THEN 1 END) AS correct_batches_count,
        -- Подсчет суммарного количества ошибок (по числу разделителей '; ')
        SUM(
            CASE 
                WHEN bvs.errors IS NULL THEN 0
                ELSE CARDINALITY(STRING_TO_ARRAY(bvs.errors, '; '))
            END
        ) AS total_parameter_errors
    FROM employees e
    JOIN batch_validation_stat bvs ON e.id = bvs.employee_id
    GROUP BY e.id, e.name
)
SELECT
    DENSE_RANK() OVER (
        ORDER BY total_parameter_errors ASC, correct_batches_count DESC
    ) AS "Рейтинг (Лучший стрелок)",
    employee_name AS "Сотрудник / Стрелок",
    total_batches AS "Всего пачек",
    correct_batches_count AS "Корректных пачек",
    error_batches_count AS "Пачек с ошибками",
    total_parameter_errors AS "Количество допущенных ошибок в параметрах",
    ROUND(correct_batches_count::NUMERIC / NULLIF(total_batches, 0) * 100.0, 1) || '%' AS "Точность ввода (%)"
FROM user_error_aggregation
ORDER BY "Рейтинг (Лучший стрелок)";


-- ЗАПРОС 3: Демонстрация расчета заголовка «Метео приближенный»
WITH valid_batches AS (
    SELECT
        b.id AS batch_id,
        b.code AS batch_code,
        b.created_at,
        et.name AS equipment_type,
        MAX(CASE WHEN pt.code = 'HEIGHT' THEN p.value END) AS height,
        MAX(CASE WHEN pt.code = 'TEMPERATURE' THEN p.value END) AS temperature,
        MAX(CASE WHEN pt.code = 'PRESSURE' THEN p.value END) AS pressure
    FROM batches b
    JOIN equipment_types et ON b.equipment_type_id = et.id
    JOIN parameters p ON p.batch_id = b.id
    JOIN parameter_types pt ON p.parameter_type_id = pt.id
    WHERE b.id IN (301, 302, 303, 304, 305, 306, 309)
    GROUP BY b.id, b.code, b.created_at, et.name
)
SELECT
    batch_code AS "Код пачки",
    created_at AS "Время зондирования",
    equipment_type AS "Прибор",
    height AS "H (м)",
    temperature AS "T (°C)",
    pressure AS "P (мм рт. ст.)",
    calc_meteo_ddchm(created_at) AS "ДДЧЧМ",
    calc_meteo_vvvv(height) AS "ВВВВ",
    calc_meteo_bbb(pressure) AS "БББ",
    calc_meteo_tt(temperature) AS "ТТ",
    calc_meteo_bbbtt(pressure, temperature) AS "БББТТ",
    calc_meteo_bulletin_header(created_at, height, pressure, temperature) AS "Полный заголовок бюллетеня"
FROM valid_batches
ORDER BY batch_id;
