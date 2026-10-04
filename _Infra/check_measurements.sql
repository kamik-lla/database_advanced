-- 1. Каждый пользователь имеет одинаковое количество измерений?
SELECT 
    u.id AS user_id,
    u.name AS user_name,
    COUNT(DISTINCT b.id) AS batches_count,
    COUNT(p.id) AS measurements_count
FROM users u
LEFT JOIN batches b ON b.user_id = u.id
LEFT JOIN parameters p ON p.batch_id = b.id
GROUP BY u.id, u.name
ORDER BY u.id;

-- 2. У нас нет пустых пачек измерения?
SELECT 
    b.id AS batch_id,
    b.code AS batch_code,
    b.created_at,
    COUNT(p.id) AS measurements_count
FROM batches b
LEFT JOIN parameters p ON p.batch_id = b.id
GROUP BY b.id, b.code, b.created_at
HAVING COUNT(p.id) = 0;

-- 3. Каждая пачка измерений содержит полное количество параметров (5 шт)?
SELECT 
    b.id AS batch_id,
    b.code AS batch_code,
    et.name AS equipment_type,
    COUNT(p.id) AS parameters_count,
    CASE 
        WHEN COUNT(p.id) = 5 THEN 'Корректно (5 параметров)'
        ELSE 'Ошибка: не 5 параметров (' || COUNT(p.id) || ')'
    END AS status
FROM batches b
JOIN equipment_types et ON b.equipment_type_id = et.id
LEFT JOIN parameters p ON p.batch_id = b.id
GROUP BY b.id, b.code, et.name
ORDER BY b.id;

-- 4. Все значения корректны и в рамках нужных диапазонов?
SELECT 
    pt.id AS param_type_id,
    pt.name AS parameter_name,
    u.name AS unit_name,
    MIN(p.value) AS actual_min,
    MAX(p.value) AS actual_max,
    CASE pt.id
        WHEN 1 THEN '[-100 .. 5000]'
        WHEN 2 THEN '[-58.0 .. 58.0]'
        WHEN 3 THEN '[500 .. 900]'
        WHEN 4 THEN '[0 .. 59]'
        WHEN 5 THEN '[0 .. 15]'
        WHEN 6 THEN '[0 .. 150]'
    END AS allowed_range,
    CASE 
        WHEN pt.id = 1 AND MIN(p.value) >= -100 AND MAX(p.value) <= 5000 THEN 'В норме'
        WHEN pt.id = 2 AND MIN(p.value) >= -58.0 AND MAX(p.value) <= 58.0 THEN 'В норме'
        WHEN pt.id = 3 AND MIN(p.value) >= 500 AND MAX(p.value) <= 900 THEN 'В норме'
        WHEN pt.id = 4 AND MIN(p.value) >= 0 AND MAX(p.value) <= 59 THEN 'В норме'
        WHEN pt.id = 5 AND MIN(p.value) >= 0 AND MAX(p.value) <= 15 THEN 'В норме'
        WHEN pt.id = 6 AND MIN(p.value) >= 0 AND MAX(p.value) <= 150 THEN 'В норме'
        ELSE 'Нарушение'
    END AS status
FROM parameter_types pt
JOIN units u ON pt.unit_id = u.id
JOIN parameters p ON p.parameter_type_id = pt.id
GROUP BY pt.id, pt.name, u.name
ORDER BY pt.id;

-- 5. Все единицы измерения верны и корректны по отношению к указанным параметрам?
SELECT 
    pt.id AS param_type_id,
    pt.name AS parameter_name,
    u.name AS unit_name,
    bu.name AS base_unit_name,
    CASE 
        WHEN pt.code = 'HEIGHT' AND u.code = 'M' AND bu.code = 'LENGTH' THEN 'Корректно'
        WHEN pt.code = 'TEMPERATURE' AND u.code = 'CELSIUS' AND bu.code = 'TEMPERATURE' THEN 'Корректно'
        WHEN pt.code = 'PRESSURE' AND u.code = 'MMHG' AND bu.code = 'PRESSURE' THEN 'Корректно'
        WHEN pt.code = 'WIND_DIRECTION' AND u.code = 'MIL' AND bu.code = 'ANGLE' THEN 'Корректно'
        WHEN pt.code = 'WIND_SPEED' AND u.code = 'MPS' AND bu.code = 'SPEED' THEN 'Корректно'
        WHEN pt.code = 'BULLET_DRIFT' AND u.code = 'M' AND bu.code = 'LENGTH' THEN 'Корректно'
        ELSE 'Ошибка: неверная единица'
    END AS status
FROM parameter_types pt
JOIN units u ON pt.unit_id = u.id
JOIN base_units bu ON u.base_unit_id = bu.id
ORDER BY pt.id;
