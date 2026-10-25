-- ХРАНЕНИЕ КОНСТАНТ, РАСШИРЕНИЕ DDL, ТИПЫ И PL/pgSQL ФУНКЦИИ
DO $$
BEGIN
    -- 1. ТАБЛИЦЫ ДЛЯ ХРАНЕНИЯ КОНСТАНТ
    
    -- 1.1 Базовые константы методики Метео-11
    CREATE TABLE IF NOT EXISTS meteo_constants (
        code        VARCHAR(50) PRIMARY KEY,
        name        VARCHAR(100) NOT NULL,
        num_value   NUMERIC(10,2) NOT NULL,
        unit        VARCHAR(20),
        description TEXT
    );

    COMMENT ON TABLE meteo_constants IS 'Справочник физических и табличных констант расчета Метео-11';

    INSERT INTO meteo_constants (code, name, num_value, unit, description) VALUES
        ('P_STANDARD',      'Табличное давление атмосферы',        750.0, 'мм рт. ст.', 'Базовое табличное давление H0 на уровне метеостанции'),
        ('T_STANDARD',      'Табличная виртуальная температура',    15.9, '°C',         'Базовая табличная приземная виртуальная температура'),
        ('PRESS_NEG_SHIFT', 'Сдвиг отрицательного давления',       500.0, 'код',        'Базовое смещение для отрицательных отклонений давления (префикс 5)'),
        ('TEMP_NEG_SHIFT',  'Сдвиг отрицательной температуры',      50.0, 'код',        'Смещение при отрицательных отклонениях температуры (к модулю + 50)')
    ON CONFLICT (code) DO UPDATE
    SET num_value = EXCLUDED.num_value, description = EXCLUDED.description;

    -- 1.2 Константы правил валидации метеопараметров
    CREATE TABLE IF NOT EXISTS parameter_validation_rules (
        param_code      VARCHAR(30) PRIMARY KEY,
        name            VARCHAR(100) NOT NULL,
        min_value       NUMERIC(10,2),
        max_value       NUMERIC(10,2),
        unit_name       VARCHAR(30) NOT NULL,
        applicable_eq   VARCHAR(20), -- 'DMK', 'VR' или NULL (для обоих)
        error_msg_range TEXT NOT NULL,
        error_msg_null  TEXT NOT NULL
    );

    COMMENT ON TABLE parameter_validation_rules IS 'Константы допустимых диапазонов и правил проверки параметров (ТЗ Метео-11)';

    INSERT INTO parameter_validation_rules 
        (param_code, name, min_value, max_value, unit_name, applicable_eq, error_msg_range, error_msg_null)
    VALUES
        ('HEIGHT',       'Высота метеопоста',     -100.0, 5000.0, 'м',          NULL,  'Высота вне диапазона [-100..5000] м',                  'Не указана высота метеопоста'),
        ('TEMPERATURE',  'Температура воздуха',    -58.0,   58.0, '°C',         NULL,  'Температура вне диапазона [-58..58] °C',               'Не указана температура воздуха'),
        ('PRESSURE',     'Атмосферное давление',   500.0,  900.0, 'мм рт. ст.', NULL,  'Давление вне диапазона [500..900] мм рт. ст.',         'Не указано атмосферное давление'),
        ('WIND_DIR',     'Направление ветра',        0.0,   59.0, 'дел. угл.',  NULL,  'Направление ветра вне диапазона [0..59] дел. угл.',    'Не указано направление ветра'),
        ('WIND_SPEED',   'Скорость ветра',           0.0,   15.0, 'м/с',        'DMK', 'Скорость ветра вне диапазона [0..15] м/с (только ДМК)', 'Для ДМК не указана скорость ветра'),
        ('BULLET_DRIFT', 'Дальность сноса пуль',     0.0,  150.0, 'м',          'VR',  'Дальность сноса пуль вне [0..150] м (только ВР)',       'Для ВР не указана дальность сноса пуль')
    ON CONFLICT (param_code) DO UPDATE
    SET min_value = EXCLUDED.min_value, max_value = EXCLUDED.max_value, applicable_eq = EXCLUDED.applicable_eq;

    -- 1.3 Таблица констант поправок температуры
    CREATE TABLE IF NOT EXISTS calc_temperature_correction (
        temperature NUMERIC(8,2) NOT NULL PRIMARY KEY,
        correction  NUMERIC(8,2) NOT NULL
    );

    INSERT INTO calc_temperature_correction (temperature, correction) VALUES
        (0.0,  0.5),
        (5.0,  0.5),
        (10.0, 1.0),
        (15.0, 1.0),
        (20.0, 1.5),
        (25.0, 2.0),
        (30.0, 3.5),
        (40.0, 4.5)
    ON CONFLICT (temperature) DO UPDATE SET correction = EXCLUDED.correction;

    -- 2. РАСШИРЕНИЕ DDL СТРУКТУР (ИНФОРМАЦИЯ ОБ ОШИБКАХ)

    -- 2.1 Справочник пользователей/сотрудников
    CREATE SEQUENCE IF NOT EXISTS seq_employees_id;
    CREATE TABLE IF NOT EXISTS employees (
        id INT DEFAULT nextval('seq_employees_id') PRIMARY KEY,
        code VARCHAR(20) NOT NULL UNIQUE,
        name VARCHAR(150) NOT NULL,
        birthday DATE,
        position_id INT
    );

    INSERT INTO employees (id, code, name) VALUES
        (1, 'EMP_01', 'Воловиков Александр Сергеевич'),
        (2, 'EMP_02', 'Иванов Петр Иванович'),
        (3, 'EMP_03', 'Сидоров Алексей Викторович')
    ON CONFLICT (id) DO NOTHING;

    -- 2.2 Справочник оборудования
    CREATE SEQUENCE IF NOT EXISTS seq_equipment_types_id;
    CREATE TABLE IF NOT EXISTS equipment_types (
        id INT DEFAULT nextval('seq_equipment_types_id') PRIMARY KEY,
        code VARCHAR(20) NOT NULL UNIQUE,
        name VARCHAR(100) NOT NULL,
        description TEXT
    );

    INSERT INTO equipment_types (id, code, name, description) VALUES
        (1, 'DMK', 'ДМК', 'Десантный метеорологический комплект'),
        (2, 'VR', 'ВР', 'Ветровое ружье')
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, code = EXCLUDED.code;

    -- 2.3 Справочник типов параметров
    CREATE SEQUENCE IF NOT EXISTS seq_parameter_types_id;
    CREATE TABLE IF NOT EXISTS parameter_types (
        id INT DEFAULT nextval('seq_parameter_types_id') PRIMARY KEY,
        code VARCHAR(30) NOT NULL UNIQUE,
        name VARCHAR(100) NOT NULL,
        unit_id INT,
        equipment_type_id INT
    );

    INSERT INTO parameter_types (id, code, name, unit_id, equipment_type_id) VALUES
        (1, 'HEIGHT', 'Высота метеопоста', 1, NULL),
        (2, 'TEMPERATURE', 'Температура воздуха', 2, NULL),
        (3, 'PRESSURE', 'Атмосферное давление', 3, NULL),
        (4, 'WIND_DIR', 'Направление ветра', 4, NULL),
        (5, 'WIND_SPEED', 'Скорость ветра', 5, 1),
        (6, 'BULLET_DRIFT', 'Дальность сноса пуль', 1, 2)
    ON CONFLICT (id) DO UPDATE SET code = EXCLUDED.code, name = EXCLUDED.name;

    -- 2.4 Пачки измерений и расширение DDL: информация об ошибках пачки
    CREATE SEQUENCE IF NOT EXISTS seq_batches_id;
    CREATE TABLE IF NOT EXISTS batches (
        id INT DEFAULT nextval('seq_batches_id') PRIMARY KEY,
        code VARCHAR(30) NOT NULL,
        employee_id INT REFERENCES employees(id),
        equipment_type_id INT REFERENCES equipment_types(id),
        created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    ALTER TABLE batches ADD COLUMN IF NOT EXISTS has_error BOOLEAN DEFAULT FALSE;
    ALTER TABLE batches ADD COLUMN IF NOT EXISTS error_message TEXT;
    COMMENT ON COLUMN batches.has_error IS 'Флаг: содержит ли пачка некорректные параметры';
    COMMENT ON COLUMN batches.error_message IS 'Текстовое описание ошибок входных параметров';

    -- 2.5 Параметры и расширение DDL: статус валидации каждого параметра
    CREATE SEQUENCE IF NOT EXISTS seq_parameters_id;
    CREATE TABLE IF NOT EXISTS parameters (
        id INT DEFAULT nextval('seq_parameters_id') PRIMARY KEY,
        code VARCHAR(50) NOT NULL,
        batch_id INT REFERENCES batches(id) ON DELETE CASCADE,
        parameter_type_id INT REFERENCES parameter_types(id),
        value NUMERIC(10,2)
    );

    ALTER TABLE parameters ADD COLUMN IF NOT EXISTS is_valid BOOLEAN DEFAULT TRUE;
    ALTER TABLE parameters ADD COLUMN IF NOT EXISTS validation_error TEXT;
    COMMENT ON COLUMN parameters.is_valid IS 'Флаг корректности отдельного значения параметра';
    COMMENT ON COLUMN parameters.validation_error IS 'Текст ошибки отдельного параметра';

    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_parameters_value_ranges') THEN
        ALTER TABLE parameters DROP CONSTRAINT chk_parameters_value_ranges;
    END IF;

    -- 3. НОВЫЙ СОСТАВНОЙ ТИП ДАННЫХ: СПИСОК ПАРАМЕТРОВ
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'measurement_params') THEN
        CREATE TYPE measurement_params AS (
            equipment_type_code VARCHAR(20),
            height              NUMERIC,
            temperature         NUMERIC,
            pressure            NUMERIC,
            wind_direction      NUMERIC,
            wind_speed          NUMERIC,
            bullet_drift        NUMERIC
        );
    END IF;

    COMMENT ON TYPE measurement_params IS 'Составной тип списка параметров метеорологического измерения';

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpolation_params') THEN
        CREATE TYPE interpolation_params AS (
            x0 NUMERIC,
            y0 NUMERIC,
            x1 NUMERIC,
            y1 NUMERIC
        );
    END IF;

END;
$$;


-- 4. ФУНКЦИЯ ПРОВЕРКИ КОРРЕКТНОСТИ ПАРАМЕТРОВ

CREATE OR REPLACE FUNCTION validate_measurement_params(p_params measurement_params)
RETURNS TEXT
LANGUAGE plpgsql
AS $func$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_eq     VARCHAR(20);
    r_height parameter_validation_rules%ROWTYPE;
    r_temp   parameter_validation_rules%ROWTYPE;
    r_press  parameter_validation_rules%ROWTYPE;
    r_wdir   parameter_validation_rules%ROWTYPE;
    r_wspd   parameter_validation_rules%ROWTYPE;
    r_drift  parameter_validation_rules%ROWTYPE;
BEGIN
    IF p_params IS NULL THEN
        RETURN 'Параметры измерения не переданы (NULL)';
    END IF;
    v_eq := UPPER(TRIM(COALESCE(p_params.equipment_type_code, '')));
    IF v_eq IN ('ДМК', 'EQ_DMK') THEN v_eq := 'DMK'; END IF;
    IF v_eq IN ('ВР', 'EQ_VR')   THEN v_eq := 'VR';  END IF;

    SELECT * INTO r_height FROM parameter_validation_rules WHERE param_code = 'HEIGHT';
    SELECT * INTO r_temp   FROM parameter_validation_rules WHERE param_code = 'TEMPERATURE';
    SELECT * INTO r_press  FROM parameter_validation_rules WHERE param_code = 'PRESSURE';
    SELECT * INTO r_wdir   FROM parameter_validation_rules WHERE param_code = 'WIND_DIR';
    SELECT * INTO r_wspd   FROM parameter_validation_rules WHERE param_code = 'WIND_SPEED';
    SELECT * INTO r_drift  FROM parameter_validation_rules WHERE param_code = 'BULLET_DRIFT';

    -- Проверка оборудования
    IF v_eq NOT IN ('DMK', 'VR') OR v_eq IS NULL OR v_eq = '' THEN
        v_errors := ARRAY_APPEND(v_errors, 'Недопустимый тип оборудования (допустимо: ДМК или ВР)');
    END IF;

    -- Проверка высоты метеопоста
    IF p_params.height IS NULL THEN
        v_errors := ARRAY_APPEND(v_errors, r_height.error_msg_null);
    ELSIF p_params.height < r_height.min_value OR p_params.height > r_height.max_value THEN
        v_errors := ARRAY_APPEND(v_errors, r_height.error_msg_range || ' (' || p_params.height || ')');
    END IF;

    -- Проверка температуры воздуха
    IF p_params.temperature IS NULL THEN
        v_errors := ARRAY_APPEND(v_errors, r_temp.error_msg_null);
    ELSIF p_params.temperature < r_temp.min_value OR p_params.temperature > r_temp.max_value THEN
        v_errors := ARRAY_APPEND(v_errors, r_temp.error_msg_range || ' (' || p_params.temperature || ')');
    END IF;

    -- Проверка атмосферного давления
    IF p_params.pressure IS NULL THEN
        v_errors := ARRAY_APPEND(v_errors, r_press.error_msg_null);
    ELSIF p_params.pressure < r_press.min_value OR p_params.pressure > r_press.max_value THEN
        v_errors := ARRAY_APPEND(v_errors, r_press.error_msg_range || ' (' || p_params.pressure || ')');
    END IF;

    -- Проверка направления ветра
    IF p_params.wind_direction IS NULL THEN
        v_errors := ARRAY_APPEND(v_errors, r_wdir.error_msg_null);
    ELSIF p_params.wind_direction < r_wdir.min_value OR p_params.wind_direction > r_wdir.max_value THEN
        v_errors := ARRAY_APPEND(v_errors, r_wdir.error_msg_range || ' (' || p_params.wind_direction || ')');
    END IF;

    -- Проверка скорости ветра (только для ДМК)
    IF v_eq = 'DMK' THEN
        IF p_params.wind_speed IS NULL THEN
            v_errors := ARRAY_APPEND(v_errors, r_wspd.error_msg_null);
        ELSIF p_params.wind_speed < r_wspd.min_value OR p_params.wind_speed > r_wspd.max_value THEN
            v_errors := ARRAY_APPEND(v_errors, r_wspd.error_msg_range || ' (' || p_params.wind_speed || ')');
        END IF;

        IF p_params.bullet_drift IS NOT NULL THEN
            v_errors := ARRAY_APPEND(v_errors, 'Дальность сноса пуль не должна быть указана для ДМК');
        END IF;
    END IF;

    -- Проверка дальности сноса пуль (только для ВР)
    IF v_eq = 'VR' THEN
        IF p_params.bullet_drift IS NULL THEN
            v_errors := ARRAY_APPEND(v_errors, r_drift.error_msg_null);
        ELSIF p_params.bullet_drift < r_drift.min_value OR p_params.bullet_drift > r_drift.max_value THEN
            v_errors := ARRAY_APPEND(v_errors, r_drift.error_msg_range || ' (' || p_params.bullet_drift || ')');
        END IF;

        IF p_params.wind_speed IS NOT NULL THEN
            v_errors := ARRAY_APPEND(v_errors, 'Скорость ветра не должна быть указана для ВР');
        END IF;
    END IF;

    IF CARDINALITY(v_errors) > 0 THEN
        RETURN ARRAY_TO_STRING(v_errors, '; ');
    END IF;

    RETURN NULL;
END;
$func$;

COMMENT ON FUNCTION validate_measurement_params(measurement_params) IS 'Функция валидации параметров метеорологического измерения по правилам из таблиц констант';


-- 5. ФУНКЦИИ ЛИНЕЙНОЙ ИНТЕРПОЛЯЦИИ

CREATE OR REPLACE FUNCTION get_interpolation_params(p_temp NUMERIC)
RETURNS interpolation_params
LANGUAGE plpgsql
AS $func$
DECLARE
    v_res interpolation_params;
    v_max_temp NUMERIC;
    v_max_corr NUMERIC;
BEGIN
    IF p_temp IS NULL THEN RETURN NULL; END IF;
    IF p_temp < 0 THEN RETURN (0.0, 0.0, 0.0, 0.0)::interpolation_params; END IF;

    SELECT temperature, correction INTO v_max_temp, v_max_corr
    FROM calc_temperature_correction ORDER BY temperature DESC LIMIT 1;

    IF p_temp >= v_max_temp THEN
        RETURN (v_max_temp, v_max_corr, v_max_temp, v_max_corr)::interpolation_params;
    END IF;

    SELECT l.temperature, l.correction, u.temperature, u.correction
    INTO v_res.x0, v_res.y0, v_res.x1, v_res.y1
    FROM (
        SELECT temperature, correction FROM calc_temperature_correction
        WHERE temperature <= p_temp ORDER BY temperature DESC LIMIT 1
    ) l
    CROSS JOIN (
        SELECT temperature, correction FROM calc_temperature_correction
        WHERE temperature > p_temp ORDER BY temperature ASC LIMIT 1
    ) u;

    RETURN v_res;
END;
$func$;

CREATE OR REPLACE FUNCTION calculate_interpolation(p_x NUMERIC, p_params interpolation_params)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $func$
BEGIN
    IF p_x IS NULL OR p_params IS NULL THEN RETURN NULL; END IF;
    IF p_params.x1 = p_params.x0 OR p_params.x1 IS NULL OR p_params.x0 IS NULL THEN
        RETURN COALESCE(p_params.y0, 0.0);
    END IF;

    RETURN ROUND(
        p_params.y0 + ((p_params.y1 - p_params.y0) / (p_params.x1 - p_params.x0)) * (p_x - p_params.x0),
        4
    );
END;
$func$;


-- 6. ФУНКЦИИ РАСЧЕТА ЗАГОЛОВКА «МЕТЕО ПРИБЛИЖЕННЫЙ» (ДДЧЧМ, ВВВВ, БББТТ)

-- Расчет группы даты и времени зондирования
CREATE OR REPLACE FUNCTION calc_meteo_ddchm(p_date TIMESTAMP)
RETURNS VARCHAR(5)
LANGUAGE plpgsql
AS $func$
BEGIN
    IF p_date IS NULL THEN RETURN NULL; END IF;
    RETURN TO_CHAR(p_date, 'DDHH24') || (EXTRACT(MINUTE FROM p_date)::INT / 10)::TEXT;
END;
$func$;

COMMENT ON FUNCTION calc_meteo_ddchm(TIMESTAMP) IS 'Расчет блока ДДЧЧМ (день, час, десятки минут) по системной дате/времени зондирования';

-- 6.2 Расчет группы высоты метеопоста
CREATE OR REPLACE FUNCTION calc_meteo_vvvv(p_height NUMERIC)
RETURNS VARCHAR(4)
LANGUAGE plpgsql
AS $func$
BEGIN
    IF p_height IS NULL THEN RETURN NULL; END IF;
    IF p_height >= 0 THEN
        RETURN LPAD(ROUND(p_height)::TEXT, 4, '0');
    ELSE
        RETURN '5' || LPAD(ROUND(ABS(p_height))::TEXT, 3, '0');
    END IF;
END;
$func$;

COMMENT ON FUNCTION calc_meteo_vvvv(NUMERIC) IS 'Расчет блока ВВВВ (высота расположения метеопоста над уровнем моря, 4 знака)';

-- 6.3 Расчет группы отклонения давления
CREATE OR REPLACE FUNCTION calc_meteo_bbb(p_pressure NUMERIC)
RETURNS VARCHAR(3)
LANGUAGE plpgsql
AS $func$
DECLARE
    v_p_std NUMERIC;
    v_diff  INT;
BEGIN
    IF p_pressure IS NULL THEN RETURN NULL; END IF;

    SELECT num_value INTO v_p_std FROM meteo_constants WHERE code = 'P_STANDARD';
    v_p_std := COALESCE(v_p_std, 750.0);

    v_diff := ROUND(p_pressure - v_p_std);

    IF v_diff >= 0 THEN
        RETURN LPAD(v_diff::TEXT, 3, '0');
    ELSE
        RETURN (500 + ABS(v_diff))::TEXT;
    END IF;
END;
$func$;

COMMENT ON FUNCTION calc_meteo_bbb(NUMERIC) IS 'Расчет блока БББ (отклонение наземного давления от табличного 750 мм рт. ст.)';

-- 6.4 Расчет группы отклонения виртуальной температуры
CREATE OR REPLACE FUNCTION calc_meteo_tt(p_temperature NUMERIC)
RETURNS VARCHAR(2)
LANGUAGE plpgsql
AS $func$
DECLARE
    v_t_std    NUMERIC;
    v_params   interpolation_params;
    v_delta_tv NUMERIC;
    v_t0       NUMERIC;
    v_diff     INT;
BEGIN
    IF p_temperature IS NULL THEN RETURN NULL; END IF;

    SELECT num_value INTO v_t_std FROM meteo_constants WHERE code = 'T_STANDARD';
    v_t_std := COALESCE(v_t_std, 15.9);

    -- Определение поправки интерполяцией
    v_params := get_interpolation_params(p_temperature);
    v_delta_tv := calculate_interpolation(p_temperature, v_params);
    v_t0 := p_temperature + COALESCE(v_delta_tv, 0.0);

    v_diff := ROUND(v_t0 - v_t_std);

    IF v_diff >= 0 THEN
        RETURN LPAD(v_diff::TEXT, 2, '0');
    ELSE
        RETURN (50 + ABS(v_diff))::TEXT;
    END IF;
END;
$func$;

COMMENT ON FUNCTION calc_meteo_tt(NUMERIC) IS 'Расчет блока ТТ (отклонение наземной виртуальной температуры от табличной +15.9°C)';

-- 6.5 Расчет совместной группы давления и температуры
CREATE OR REPLACE FUNCTION calc_meteo_bbbtt(p_pressure NUMERIC, p_temperature NUMERIC)
RETURNS VARCHAR(5)
LANGUAGE plpgsql
AS $func$
BEGIN
    IF p_pressure IS NULL OR p_temperature IS NULL THEN RETURN NULL; END IF;
    RETURN calc_meteo_bbb(p_pressure) || calc_meteo_tt(p_temperature);
END;
$func$;

COMMENT ON FUNCTION calc_meteo_bbbtt(NUMERIC, NUMERIC) IS 'Расчет совместного 5-значного блока БББТТ (отклонение давления и температуры)';

-- 6.6 Формирование полного заголовка приближенного бюллетеня
CREATE OR REPLACE FUNCTION calc_meteo_bulletin_header(
    p_date        TIMESTAMP,
    p_height      NUMERIC,
    p_pressure    NUMERIC,
    p_temperature NUMERIC
)
RETURNS VARCHAR(20)
LANGUAGE plpgsql
AS $func$
BEGIN
    RETURN calc_meteo_ddchm(p_date) || ' ' || 
           calc_meteo_vvvv(p_height) || ' ' || 
           calc_meteo_bbbtt(p_pressure, p_temperature);
END;
$func$;

COMMENT ON FUNCTION calc_meteo_bulletin_header(TIMESTAMP, NUMERIC, NUMERIC, NUMERIC) IS 'Формирование полного заголовка бюллетеня «Метео приближенный» формата: ДДЧЧМ ВВВВ БББТТ';
