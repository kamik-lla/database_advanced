-- scriptDz7_3_meteo_report.sql
-- Расчет «Метео приближенный» (ДДЧМ, ВВВВ, БББТТ) для каждой пачки

WITH meteo_data AS (
    -- Сбор идентификаторов, метаданных сотрудников и вычисленных групп бюллетеня
    SELECT
        b.id AS batch_id,
        b.code AS batch_code,
        e.code AS employee_code,
        pos.name AS position_name,
        et.name AS equipment_name,
        calc_meteo_ddchm(b.id) AS ddchm,
        calc_meteo_vvvv(b.id)  AS vvvv,
        calc_meteo_bbbtt(b.id) AS bbbtt
    FROM batches b
    JOIN employees e ON e.id = b.employee_id
    LEFT JOIN positions pos ON pos.id = e.position_id
    JOIN equipment_types et ON et.id = b.equipment_type_id
    WHERE b.id IN (
        -- Отображаем только валидные пачки без ошибок параметров
        SELECT DISTINCT b2.id
        FROM batches b2
        JOIN parameters p ON p.batch_id = b2.id
        GROUP BY b2.id, b2.equipment_type_id
        HAVING validate_measurement_params(
            ROW(
                MAX(CASE WHEN p.parameter_type_id = 1 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 2 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 3 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 4 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 5 THEN p.value END),
                MAX(CASE WHEN p.parameter_type_id = 6 THEN p.value END)
            )::measurement_params,
            b2.equipment_type_id
        ) IS NULL
    )
)
SELECT
    ROW_NUMBER() OVER (ORDER BY batch_id) AS "№",
    batch_code AS "Код пачки",
    employee_code AS "Код сотрудника",
    position_name AS "Должность",
    equipment_name AS "Оборудование",
    ddchm AS "ДДЧМ (дата/время)",
    vvvv  AS "ВВВВ (высота)",
    bbbtt AS "БББТТ (давление и темп.)",
    'МЕТЕО ПРИБЛИЖЕННЫЙ ' || ddchm || ' ' || vvvv || ' ' || bbbtt AS "Итоговый бюллетень"
FROM meteo_data
ORDER BY batch_id;
