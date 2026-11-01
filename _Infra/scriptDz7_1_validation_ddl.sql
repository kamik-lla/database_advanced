-- scriptDz7_1_validation_ddl.sql
-- DDL для валидации параметров, констант и функций расчета «Метео приближенный»
-- Запускается после миграции схемы и скрипта интерполяции (ДЗ 5 и ДЗ 6)

-- ЧАСТЬ 1: DO-блок — создание таблиц констант, справочника ошибок и типов
DO $do$
BEGIN
    -- 1. Удаление старых функций и типов при необходимости пересоздания
    DROP FUNCTION IF EXISTS calc_meteo_bulletin_header(TIMESTAMP, NUMERIC, NUMERIC, NUMERIC) CASCADE;
    DROP FUNCTION IF EXISTS calc_meteo_bbbtt(INT) CASCADE;
    DROP FUNCTION IF EXISTS calc_meteo_bbbtt(NUMERIC, NUMERIC) CASCADE;
    DROP FUNCTION IF EXISTS calc_meteo_tt(NUMERIC) CASCADE;
    DROP FUNCTION IF EXISTS calc_meteo_bbb(NUMERIC) CASCADE;
    DROP FUNCTION IF EXISTS calc_meteo_vvvv(INT) CASCADE;
    DROP FUNCTION IF EXISTS calc_meteo_vvvv(NUMERIC) CASCADE;
    DROP FUNCTION IF EXISTS calc_meteo_ddchm(INT) CASCADE;
    DROP FUNCTION IF EXISTS calc_meteo_ddchm(TIMESTAMP) CASCADE;
    DROP FUNCTION IF EXISTS validate_measurement_params(measurement_params, INT) CASCADE;
    DROP FUNCTION IF EXISTS validate_measurement_params(measurement_params) CASCADE;
    DROP TYPE IF EXISTS measurement_params CASCADE;
    DROP TABLE IF EXISTS parameter_validation_rules CASCADE;
    DROP TABLE IF EXISTS meteo_constants CASCADE;
    DROP TABLE IF EXISTS error_messages CASCADE;

    -- 2. Справочник текстов ошибок валидации (вынесение текстов ошибок в настройки)
    CREATE TABLE error_messages (
        error_code VARCHAR(50) PRIMARY KEY,
        error_text TEXT NOT NULL
    );
    COMMENT ON TABLE error_messages IS 'Справочник текстов ошибок валидации входных метеопараметров';
    COMMENT ON COLUMN error_messages.error_code IS 'Уникальный строковый код ошибки';
    COMMENT ON COLUMN error_messages.error_text IS 'Текст сообщения об ошибке для отчета';

    INSERT INTO error_messages (error_code, error_text) VALUES
        ('EQ_INVALID',          'Недопустимый тип оборудования (допустимо: ДМК или ВР)'),
        ('HEIGHT_NULL',         'Не указана высота метеопоста'),
        ('HEIGHT_INTEGER',      'Высота метеопоста: значение должно быть целым числом'),
        ('HEIGHT_RANGE',        'Высота метеопоста: значение вне допустимого диапазона [-100..5000] м'),
        ('TEMP_NULL',           'Не указана температура воздуха'),
        ('TEMP_RANGE',          'Температура воздуха: значение вне допустимого диапазона [-58..58] °C'),
        ('TEMP_DECIMAL',        'Температура воздуха: допускается не более 1 знака после запятой'),
        ('PRESS_NULL',          'Не указано атмосферное давление'),
        ('PRESS_INTEGER',       'Атмосферное давление: значение должно быть целым числом'),
        ('PRESS_RANGE',         'Атмосферное давление: значение вне допустимого диапазона [500..900] мм рт. ст.'),
        ('WIND_DIR_NULL',       'Не указано направление ветра'),
        ('WIND_DIR_INTEGER',    'Направление ветра: значение должно быть целым числом'),
        ('WIND_DIR_RANGE',      'Направление ветра: значение вне допустимого диапазона [0..59] дел. угл.'),
        ('WIND_SPEED_NULL_DMK', 'Для ДМК не указана скорость ветра'),
        ('WIND_SPEED_INTEGER',  'Скорость ветра: значение должно быть целым числом'),
        ('WIND_SPEED_RANGE',    'Скорость ветра: значение вне допустимого диапазона [0..15] м/с'),
        ('WIND_SPEED_NOT_VR',   'Скорость ветра не должна указываться для ВР'),
        ('DRIFT_NULL_VR',       'Для ВР не указана дальность сноса пуль'),
        ('DRIFT_INTEGER',       'Дальность сноса пуль: значение должно быть целым числом'),
        ('DRIFT_RANGE',         'Дальность сноса пуль: значение вне допустимого диапазона [0..150] м'),
        ('DRIFT_NOT_DMK',       'Дальность сноса пуль не должна указываться для ДМК');

    -- 3. Составной тип для передачи набора параметров пачки в функцию
    CREATE TYPE measurement_params AS (
        height         NUMERIC,
        temperature    NUMERIC,
        pressure       NUMERIC,
        wind_direction NUMERIC,
        wind_speed     NUMERIC,
        bullet_drift   NUMERIC
    );
    COMMENT ON TYPE measurement_params IS 'Составной тип параметров метеорологического измерения (горизонтальная проекция пачки)';

    -- 4. Правила валидации параметров по типам оборудования
    CREATE TABLE parameter_validation_rules (
        id              INT PRIMARY KEY,
        param_code      VARCHAR(30) NOT NULL,
        equipment_id    INT NOT NULL REFERENCES equipment_types(id),
        param_name      VARCHAR(100) NOT NULL,
        min_value       NUMERIC(10,2),
        max_value       NUMERIC(10,2),
        is_integer      BOOLEAN NOT NULL DEFAULT TRUE,
        is_required     BOOLEAN NOT NULL DEFAULT TRUE,
        description     TEXT
    );
    COMMENT ON TABLE parameter_validation_rules IS 'Правила и граничные условия проверки параметров по типам оборудования';
    COMMENT ON COLUMN parameter_validation_rules.id IS 'Уникальный идентификатор правила';
    COMMENT ON COLUMN parameter_validation_rules.param_code IS 'Код параметра (HEIGHT, TEMPERATURE, PRESSURE и т.д.)';
    COMMENT ON COLUMN parameter_validation_rules.equipment_id IS 'Ссылка на тип оборудования (1 - ДМК, 2 - ВР)';
    COMMENT ON COLUMN parameter_validation_rules.min_value IS 'Нижняя допустимая граница параметра';
    COMMENT ON COLUMN parameter_validation_rules.max_value IS 'Верхняя допустимая граница параметра';
    COMMENT ON COLUMN parameter_validation_rules.is_integer IS 'Флаг обязательности целочисленного значения';
    COMMENT ON COLUMN parameter_validation_rules.is_required IS 'Флаг обязательности наличия параметра';

    -- Правила для ДМК (equipment_types id = 1): параметры 1, 2, 3, 4, 5
    INSERT INTO parameter_validation_rules (id, param_code, equipment_id, param_name, min_value, max_value, is_integer, is_required, description) VALUES
        (1, 'HEIGHT',       1, 'Высота метеопоста',   -100.0, 5000.0, TRUE,  TRUE,  'Целое число в диапазоне -100..5000 м'),
        (2, 'TEMPERATURE',  1, 'Температура воздуха',  -58.0,   58.0, FALSE, TRUE,  'Дробное (1 знак) в диапазоне -58..58 °C'),
        (3, 'PRESSURE',     1, 'Атмосферное давление', 500.0,  900.0, TRUE,  TRUE,  'Целое число в диапазоне 500..900 мм рт. ст.'),
        (4, 'WIND_DIR',     1, 'Направление ветра',      0.0,   59.0, TRUE,  TRUE,  'Целое число в диапазоне 0..59 дел. угл.'),
        (5, 'WIND_SPEED',   1, 'Скорость ветра',         0.0,   15.0, TRUE,  TRUE,  'Целое число в диапазоне 0..15 м/с (только ДМК)');

    -- Правила для ВР (equipment_types id = 2): параметры 1, 2, 3, 4, 6
    INSERT INTO parameter_validation_rules (id, param_code, equipment_id, param_name, min_value, max_value, is_integer, is_required, description) VALUES
        (6,  'HEIGHT',       2, 'Высота метеопоста',   -100.0, 5000.0, TRUE,  TRUE,  'Целое число в диапазоне -100..5000 м'),
        (7,  'TEMPERATURE',  2, 'Температура воздуха',  -58.0,   58.0, FALSE, TRUE,  'Дробное (1 знак) в диапазоне -58..58 °C'),
        (8,  'PRESSURE',     2, 'Атмосферное давление', 500.0,  900.0, TRUE,  TRUE,  'Целое число в диапазоне 500..900 мм рт. ст.'),
        (9,  'WIND_DIR',     2, 'Направление ветра',      0.0,   59.0, TRUE,  TRUE,  'Целое число в диапазоне 0..59 дел. угл.'),
        (10, 'BULLET_DRIFT', 2, 'Дальность сноса пуль',   0.0,  150.0, TRUE,  TRUE,  'Целое число в диапазоне 0..150 м (только ВР)');

    -- 5. Таблица физических и табличных констант расчета Метео-11
    CREATE TABLE meteo_constants (
        id          INT PRIMARY KEY,
        code        VARCHAR(50) NOT NULL UNIQUE,
        name        VARCHAR(100) NOT NULL,
        num_value   NUMERIC(10,2) NOT NULL,
        unit        VARCHAR(20),
        description TEXT
    );
    COMMENT ON TABLE meteo_constants IS 'Справочник физических и расчетных констант методики Метео-11';
    COMMENT ON COLUMN meteo_constants.id IS 'Уникальный номер константы';
    COMMENT ON COLUMN meteo_constants.code IS 'Строковый код константы для поиска';
    COMMENT ON COLUMN meteo_constants.name IS 'Наименование константы';
    COMMENT ON COLUMN meteo_constants.num_value IS 'Численное значение';

    INSERT INTO meteo_constants (id, code, name, num_value, unit, description) VALUES
        (1, 'P_STANDARD',      'Табличное давление атмосферы',     750.0, 'мм рт. ст.', 'Базовое табличное давление H0 на уровне метеостанции'),
        (2, 'T_STANDARD',      'Табличная виртуальная температура', 15.9, '°C',         'Базовая табличная виртуальная температура приземного слоя'),
        (3, 'PRESS_NEG_SHIFT', 'Сдвиг отрицательного давления',    500.0, 'код',        'Базовое смещение для отрицательных отклонений давления'),
        (4, 'TEMP_NEG_SHIFT',  'Сдвиг отрицательной температуры',   50.0, 'код',        'Смещение для отрицательных отклонений температуры');

END;
$do$;


-- ЧАСТЬ 2: Функции валидации и расчета Метео приближенного

-- 2.1 Функция валидации параметров измерения
-- Принимает: набор параметров (measurement_params) и id типа оборудования
-- Возвращает: текст ошибок через разделитель '; ' (пустая строка/NULL = ошибок нет)
CREATE OR REPLACE FUNCTION validate_measurement_params(
    p_params            measurement_params,
    p_equipment_type_id INT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $func$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_msg    TEXT;
    v_height NUMERIC := p_params.height;
    v_temp   NUMERIC := p_params.temperature;
    v_press  NUMERIC := p_params.pressure;
    v_wdir   NUMERIC := p_params.wind_direction;
    v_wspeed NUMERIC := p_params.wind_speed;
    v_drift  NUMERIC := p_params.bullet_drift;
BEGIN
    IF p_params IS NULL THEN
        RETURN 'Параметры измерения не переданы';
    END IF;

    -- Проверка корректности переданного типа оборудования (1 - ДМК, 2 - ВР)
    IF p_equipment_type_id NOT IN (1, 2) OR p_equipment_type_id IS NULL THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'EQ_INVALID';
        v_errors := ARRAY_APPEND(v_errors, COALESCE(v_msg, 'Недопустимый тип оборудования'));
    END IF;

    -- 1. Высота метеопоста
    IF v_height IS NULL THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'HEIGHT_NULL';
        v_errors := ARRAY_APPEND(v_errors, v_msg);
    ELSIF v_height != FLOOR(v_height) THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'HEIGHT_INTEGER';
        v_errors := ARRAY_APPEND(v_errors, v_msg);
    ELSIF v_height < -100.0 OR v_height > 5000.0 THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'HEIGHT_RANGE';
        v_errors := ARRAY_APPEND(v_errors, v_msg || ' (' || v_height || ')');
    END IF;

    -- 2. Температура воздуха
    IF v_temp IS NULL THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'TEMP_NULL';
        v_errors := ARRAY_APPEND(v_errors, v_msg);
    ELSIF v_temp < -58.0 OR v_temp > 58.0 THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'TEMP_RANGE';
        v_errors := ARRAY_APPEND(v_errors, v_msg || ' (' || v_temp || ')');
    ELSIF (v_temp * 10.0) != FLOOR(v_temp * 10.0) THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'TEMP_DECIMAL';
        v_errors := ARRAY_APPEND(v_errors, v_msg);
    END IF;

    -- 3. Атмосферное давление
    IF v_press IS NULL THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'PRESS_NULL';
        v_errors := ARRAY_APPEND(v_errors, v_msg);
    ELSIF v_press != FLOOR(v_press) THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'PRESS_INTEGER';
        v_errors := ARRAY_APPEND(v_errors, v_msg);
    ELSIF v_press < 500.0 OR v_press > 900.0 THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'PRESS_RANGE';
        v_errors := ARRAY_APPEND(v_errors, v_msg || ' (' || v_press || ')');
    END IF;

    -- 4. Направление ветра
    IF v_wdir IS NULL THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'WIND_DIR_NULL';
        v_errors := ARRAY_APPEND(v_errors, v_msg);
    ELSIF v_wdir != FLOOR(v_wdir) THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'WIND_DIR_INTEGER';
        v_errors := ARRAY_APPEND(v_errors, v_msg);
    ELSIF v_wdir < 0.0 OR v_wdir > 59.0 THEN
        SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'WIND_DIR_RANGE';
        v_errors := ARRAY_APPEND(v_errors, v_msg || ' (' || v_wdir || ')');
    END IF;

    -- 5. Скорость ветра (только для ДМК, equipment_id = 1)
    IF p_equipment_type_id = 1 THEN
        IF v_wspeed IS NULL THEN
            SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'WIND_SPEED_NULL_DMK';
            v_errors := ARRAY_APPEND(v_errors, v_msg);
        ELSIF v_wspeed != FLOOR(v_wspeed) THEN
            SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'WIND_SPEED_INTEGER';
            v_errors := ARRAY_APPEND(v_errors, v_msg);
        ELSIF v_wspeed < 0.0 OR v_wspeed > 15.0 THEN
            SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'WIND_SPEED_RANGE';
            v_errors := ARRAY_APPEND(v_errors, v_msg || ' (' || v_wspeed || ')');
        END IF;

        IF v_drift IS NOT NULL THEN
            SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'DRIFT_NOT_DMK';
            v_errors := ARRAY_APPEND(v_errors, v_msg);
        END IF;
    END IF;

    -- 6. Дальность сноса пуль (только для ВР, equipment_id = 2)
    IF p_equipment_type_id = 2 THEN
        IF v_drift IS NULL THEN
            SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'DRIFT_NULL_VR';
            v_errors := ARRAY_APPEND(v_errors, v_msg);
        ELSIF v_drift != FLOOR(v_drift) THEN
            SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'DRIFT_INTEGER';
            v_errors := ARRAY_APPEND(v_errors, v_msg);
        ELSIF v_drift < 0.0 OR v_drift > 150.0 THEN
            SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'DRIFT_RANGE';
            v_errors := ARRAY_APPEND(v_errors, v_msg || ' (' || v_drift || ')');
        END IF;

        IF v_wspeed IS NOT NULL THEN
            SELECT error_text INTO v_msg FROM error_messages WHERE error_code = 'WIND_SPEED_NOT_VR';
            v_errors := ARRAY_APPEND(v_errors, v_msg);
        END IF;
    END IF;

    IF CARDINALITY(v_errors) > 0 THEN
        RETURN ARRAY_TO_STRING(v_errors, '; ');
    END IF;

    RETURN NULL;
END;
$func$;

COMMENT ON FUNCTION validate_measurement_params(measurement_params, INT) IS 'Проверка корректности входных параметров пачки измерений по типу оборудования';


-- 2.2 Функция расчета блока даты и времени: ДДЧМ (день, час, десяток минут)
CREATE OR REPLACE FUNCTION calc_meteo_ddchm(p_batch_id INT)
RETURNS VARCHAR(5)
LANGUAGE plpgsql
AS $func$
DECLARE
    v_created_at TIMESTAMP;
BEGIN
    SELECT created_at INTO v_created_at FROM batches WHERE id = p_batch_id;
    IF v_created_at IS NULL THEN
        RETURN '00000';
    END IF;

    RETURN TO_CHAR(v_created_at, 'DDHH24') || (EXTRACT(MINUTE FROM v_created_at)::INT / 10)::TEXT;
END;
$func$;

COMMENT ON FUNCTION calc_meteo_ddchm(INT) IS 'Расчет блока ДДЧМ (день, час, десятки минут) по времени создания пачки';


-- 2.3 Функция расчета блока высоты: ВВВВ (высота метеопоста, 4 знака)
CREATE OR REPLACE FUNCTION calc_meteo_vvvv(p_batch_id INT)
RETURNS VARCHAR(4)
LANGUAGE plpgsql
AS $func$
DECLARE
    v_height NUMERIC;
BEGIN
    SELECT value INTO v_height
    FROM parameters
    WHERE batch_id = p_batch_id AND parameter_type_id = 1;

    IF v_height IS NULL THEN
        RETURN '0000';
    END IF;

    IF v_height >= 0 THEN
        RETURN LPAD(ROUND(v_height)::TEXT, 4, '0');
    ELSE
        RETURN '5' || LPAD(ROUND(ABS(v_height))::TEXT, 3, '0');
    END IF;
END;
$func$;

COMMENT ON FUNCTION calc_meteo_vvvv(INT) IS 'Расчет блока ВВВВ (высота метеопоста над уровнем моря, 4 знака) по пачке';


-- 2.4 Функция расчета совместного блока отклонения давления и температуры: БББТТ
CREATE OR REPLACE FUNCTION calc_meteo_bbbtt(p_batch_id INT)
RETURNS VARCHAR(5)
LANGUAGE plpgsql
AS $func$
DECLARE
    v_press    NUMERIC;
    v_temp     NUMERIC;
    v_p_std    NUMERIC := 750.0;
    v_t_std    NUMERIC := 15.9;
    v_p_diff   INT;
    v_t_diff   INT;
    v_bbb      VARCHAR(3);
    v_tt       VARCHAR(2);
    v_params   interpolation_params;
    v_delta_tv NUMERIC := 0.0;
    v_t0       NUMERIC;
BEGIN
    SELECT value INTO v_press
    FROM parameters
    WHERE batch_id = p_batch_id AND parameter_type_id = 3;

    SELECT value INTO v_temp
    FROM parameters
    WHERE batch_id = p_batch_id AND parameter_type_id = 2;

    IF v_press IS NULL OR v_temp IS NULL THEN
        RETURN '00000';
    END IF;

    -- Получение констант из таблицы
    SELECT COALESCE(MAX(num_value), 750.0) INTO v_p_std FROM meteo_constants WHERE code = 'P_STANDARD';
    SELECT COALESCE(MAX(num_value), 15.9)  INTO v_t_std FROM meteo_constants WHERE code = 'T_STANDARD';

    -- Расчет БББ (отклонение давления от 750 мм рт. ст.)
    v_p_diff := ROUND(v_press - v_p_std);
    IF v_p_diff >= 0 THEN
        v_bbb := LPAD(v_p_diff::TEXT, 3, '0');
    ELSE
        v_bbb := (500 + ABS(v_p_diff))::TEXT;
    END IF;

    -- Расчет ТТ (отклонение виртуальной температуры t0 от 15.9°C с учетом интерполяции)
    IF v_temp >= 0 THEN
        v_params := get_interpolation_params(v_temp);
        v_delta_tv := calculate_interpolation(v_temp, v_params);
    ELSE
        v_delta_tv := 0.0;
    END IF;

    v_t0 := v_temp + COALESCE(v_delta_tv, 0.0);
    v_t_diff := ROUND(v_t0 - v_t_std);

    IF v_t_diff >= 0 THEN
        v_tt := LPAD(v_t_diff::TEXT, 2, '0');
    ELSE
        v_tt := (50 + ABS(v_t_diff))::TEXT;
    END IF;

    RETURN v_bbb || v_tt;
END;
$func$;

COMMENT ON FUNCTION calc_meteo_bbbtt(INT) IS 'Расчет 5-значного блока БББТТ (отклонение давления и температуры) по пачке';
