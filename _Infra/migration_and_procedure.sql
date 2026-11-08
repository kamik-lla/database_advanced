-- Скрипт 1: migration_and_procedure.sql

-- 1. Базовые типы, настройки и функции интерполяции (обеспечение автономности)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'input_params_type') THEN
        CREATE TYPE input_params_type AS (
            height numeric(8,2),
            temperature numeric(8,2),
            pressure numeric(8,2),
            wind_direction numeric(8,2),
            wind_speed numeric(8,2),
            bullet_demolition_range numeric(8,2)
        );
        COMMENT ON TYPE input_params_type IS 'Составной тип входных метеорологических параметров';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'check_result_type') THEN
        CREATE TYPE check_result_type AS (
            is_check boolean,
            error_message text,
            params input_params_type
        );
        COMMENT ON TYPE check_result_type IS 'Результат проверки входных параметров';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpolation_type') THEN
        CREATE TYPE interpolation_type AS (
            x0 numeric(8,2),
            x1 numeric(8,2),
            y0 numeric(8,2),
            y1 numeric(8,2)
        );
        COMMENT ON TYPE interpolation_type IS 'Граничные точки для линейной интерполяции';
    END IF;
END $$;

-- Таблица настроек диапазонов и констант
CREATE TABLE IF NOT EXISTS public.measurment_settings (
    key character varying(100) PRIMARY KEY,
    value character varying(255),
    description text
);

INSERT INTO public.measurment_settings (key, value, description) VALUES
    ('min_temperature', '-58', 'Минимальное значение температуры'),
    ('max_temperature', '58', 'Максимальное значение температуры'),
    ('min_pressure', '500', 'Минимальное значение давления'),
    ('max_pressure', '900', 'Максимальное значение давления'),
    ('min_wind_direction', '0', 'Минимальное значение направления ветра'),
    ('max_wind_direction', '59', 'Максимальное значение направления ветра'),
    ('calc_table_temperature', '15.9', 'Табличное значение нормальной температуры'),
    ('calc_table_pressure', '750', 'Табличное значение нормального наземного давления'),
    ('min_height', '-100', 'Минимальная высота метеопоста над уровнем моря'),
    ('max_height', '5000', 'Максимальная высота метеопоста над уровнем моря')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, description = EXCLUDED.description;

-- Таблица виртуальной поправки температуры (Таблица 1 ТЗ)
CREATE TABLE IF NOT EXISTS public.calc_correction_temperature (
    temperature numeric(8,2) PRIMARY KEY,
    correction numeric(8,2) NOT NULL
);

INSERT INTO public.calc_correction_temperature (temperature, correction) VALUES
    (0.00, 0.50),
    (5.00, 0.50),
    (10.00, 1.00),
    (15.00, 1.00),
    (20.00, 1.50),
    (25.00, 2.00),
    (30.00, 3.50),
    (40.00, 4.50)
ON CONFLICT (temperature) DO UPDATE SET correction = EXCLUDED.correction;

-- Функция линейной интерполяции
CREATE OR REPLACE FUNCTION public.fn_calc_interpolation(
    par_x numeric,
    par_interpolation public.interpolation_type
)
RETURNS numeric
LANGUAGE plpgsql
AS $body$
BEGIN
    IF par_interpolation.x1 = par_interpolation.x0 THEN
        RETURN par_interpolation.y0;
    END IF;

    RETURN round(par_interpolation.y0 + (par_x - par_interpolation.x0) * 
           (par_interpolation.y1 - par_interpolation.y0) / 
           (par_interpolation.x1 - par_interpolation.x0), 2);
END;
$body$;

-- Функция расчета виртуальной поправки температуры с интерполяцией
CREATE OR REPLACE FUNCTION public.fn_calc_temperature_interpolation(
    par_temperature numeric
)
RETURNS numeric
LANGUAGE plpgsql
AS $body$
DECLARE 
    var_interpolation interpolation_type;
    var_result numeric(8,2) := 0;
    var_min_temp numeric(8,2) := 0;
    var_max_temp numeric(8,2) := 0;
BEGIN
    -- Ниже нуля по Таблице 1 виртуальная поправка равна 0
    IF par_temperature <= 0 THEN
        RETURN 0.00;
    END IF;

    IF EXISTS (SELECT 1 FROM public.calc_correction_temperature WHERE temperature = par_temperature) THEN
        SELECT correction INTO var_result 
        FROM public.calc_correction_temperature
        WHERE temperature = par_temperature;
        RETURN var_result;
    END IF;

    SELECT min(temperature), max(temperature) 
    INTO var_min_temp, var_max_temp
    FROM public.calc_correction_temperature;

    IF par_temperature > var_max_temp THEN
        SELECT correction INTO var_result 
        FROM public.calc_correction_temperature 
        WHERE temperature = var_max_temp;
        RETURN var_result;
    END IF;

    SELECT leftPart.x0, leftPart.y0, rightPart.x1, rightPart.y1
    INTO var_interpolation.x0, var_interpolation.y0, var_interpolation.x1, var_interpolation.y1
    FROM (
        SELECT temperature AS x0, correction AS y0
        FROM public.calc_correction_temperature
        WHERE temperature <= par_temperature
        ORDER BY temperature DESC
        LIMIT 1
    ) AS leftPart
    CROSS JOIN (
        SELECT temperature AS x1, correction AS y1
        FROM public.calc_correction_temperature
        WHERE temperature >= par_temperature
        ORDER BY temperature ASC
        LIMIT 1
    ) AS rightPart;

    var_result := public.fn_calc_interpolation(par_temperature, var_interpolation);
    RETURN var_result;
END;
$body$;

-- Функция формирования кода времени ДДЧЧМ
CREATE OR REPLACE FUNCTION public.fn_calc_header_period(
    par_period timestamp with time zone
)
RETURNS text
LANGUAGE plpgsql
AS $body$
BEGIN
    RETURN (
        lpad(extract(day from par_period)::text, 2, '0') ||
        lpad(extract(hour from par_period)::text, 2, '0') ||
        left(lpad(extract(minute from par_period)::text, 2, '0'), 1)
    );
END;
$body$;

-- Функция расчета отклонения наземного давления от табличного (750 мм рт. ст.)
CREATE OR REPLACE FUNCTION public.fn_calc_header_pressure(
    par_pressure numeric
)
RETURNS numeric
LANGUAGE plpgsql
AS $body$
DECLARE
    table_pressure numeric(8,2) := 750;
BEGIN
    SELECT coalesce(value::numeric(8,2), 750)
    INTO table_pressure
    FROM public.measurment_settings
    WHERE key = 'calc_table_pressure';

    RETURN par_pressure - table_pressure;
END;
$body$;

-- Функция валидации входных параметров
CREATE OR REPLACE FUNCTION public.fn_check_input_params(
    par_param input_params_type
)
RETURNS public.input_params_type
LANGUAGE plpgsql
AS $body$
DECLARE
    var_min_t numeric; var_max_t numeric;
    var_min_p numeric; var_max_p numeric;
    var_min_h numeric; var_max_h numeric;
    var_min_d numeric; var_max_d numeric;
BEGIN
    SELECT coalesce((SELECT value::numeric FROM public.measurment_settings WHERE key = 'min_temperature'), -58),
           coalesce((SELECT value::numeric FROM public.measurment_settings WHERE key = 'max_temperature'), 58),
           coalesce((SELECT value::numeric FROM public.measurment_settings WHERE key = 'min_pressure'), 500),
           coalesce((SELECT value::numeric FROM public.measurment_settings WHERE key = 'max_pressure'), 900),
           coalesce((SELECT value::numeric FROM public.measurment_settings WHERE key = 'min_height'), -100),
           coalesce((SELECT value::numeric FROM public.measurment_settings WHERE key = 'max_height'), 5000),
           coalesce((SELECT value::numeric FROM public.measurment_settings WHERE key = 'min_wind_direction'), 0),
           coalesce((SELECT value::numeric FROM public.measurment_settings WHERE key = 'max_wind_direction'), 59)
    INTO var_min_t, var_max_t, var_min_p, var_max_p, var_min_h, var_max_h, var_min_d, var_max_d;

    IF par_param.temperature < var_min_t OR par_param.temperature > var_max_t THEN
        RAISE EXCEPTION 'Температура % выходит за допустимый диапазон [%, %] °C!', 
            par_param.temperature, var_min_t, var_max_t;
    END IF;

    IF par_param.pressure < var_min_p OR par_param.pressure > var_max_p THEN
        RAISE EXCEPTION 'Давление % выходит за допустимый диапазон [%, %] мм рт. ст.!', 
            par_param.pressure, var_min_p, var_max_p;
    END IF;

    IF par_param.height < var_min_h OR par_param.height > var_max_h THEN
        RAISE EXCEPTION 'Высота % выходит за допустимый диапазон [%, %] м!', 
            par_param.height, var_min_h, var_max_h;
    END IF;

    IF par_param.wind_direction < var_min_d OR par_param.wind_direction > var_max_d THEN
        RAISE EXCEPTION 'Направление ветра % выходит за допустимый диапазон [%, %] дел. угл.!', 
            par_param.wind_direction, var_min_d, var_max_d;
    END IF;

    RETURN par_param;
END;
$body$;


-- 2. Структура справочников, нормализация заголовков и исправление данных

-- 2.1 Стандартные высоты зондирования
CREATE SEQUENCE IF NOT EXISTS calc_correction_height_seq;
CREATE TABLE IF NOT EXISTS public.calc_correction_heights (
    id integer PRIMARY KEY DEFAULT nextval('calc_correction_height_seq'),
    height integer NOT NULL UNIQUE
);

COMMENT ON TABLE public.calc_correction_heights IS 'Справочник стандартных высот зондирования атмосферы (м)';

INSERT INTO public.calc_correction_heights (id, height) VALUES
    (1, 200),
    (2, 400),
    (3, 800),
    (4, 1200),
    (5, 1600),
    (6, 2000),
    (7, 2400),
    (8, 3000),
    (9, 4000)
ON CONFLICT (id) DO UPDATE SET height = EXCLUDED.height;

SELECT setval('calc_correction_height_seq', (SELECT max(id) FROM public.calc_correction_heights));

-- 2.2 Справочник типов расчетных таблиц
CREATE SEQUENCE IF NOT EXISTS calc_correction_types_seq;
CREATE TABLE IF NOT EXISTS public.calc_correction_types (
    id integer PRIMARY KEY DEFAULT nextval('calc_correction_types_seq'),
    code character varying(50) NOT NULL UNIQUE,
    parent_id integer REFERENCES public.calc_correction_types(id) ON DELETE CASCADE,
    equipment_type_id integer REFERENCES public.equipment_types(id) ON DELETE SET NULL,
    description text NOT NULL
);

-- Нормализация: удаление массива header_values из таблицы типов таблиц при его наличии
ALTER TABLE public.calc_correction_types DROP COLUMN IF EXISTS header_values;

COMMENT ON TABLE public.calc_correction_types IS 'Иерархический справочник типов расчетных таблиц поправок';

-- Наполнение справочника типов таблиц
INSERT INTO public.calc_correction_types (id, code, parent_id, equipment_type_id, description) VALUES
    (1, 'TABLE_2', NULL, NULL, 'Таблица 2: Средние отклонения температуры воздуха (Метео-11)'),
    (2, 'TABLE_3_WIND_SPEED', NULL, NULL, 'Таблица 3: Скорость среднего ветра (Wy)'),
    (3, 'TABLE_3_WIND_DIR',   NULL, NULL, 'Таблица 3: Приращение направления среднего ветра (delta_alpha_Wy)'),
    (4, 'T2_TEMP_NEG', 1, NULL, 'Таблица 2: Отклонения температуры (отрицательные значения, числитель)'),
    (5, 'T2_TEMP_POS', 1, NULL, 'Таблица 2: Отклонения температуры (положительные значения, знаменатель)'),
    (6, 'T3_VR_WIND_SPEED', 2, 2, 'Таблица 3: Скорость среднего ветра для ВР (аргумент: дальность сноса пуль Dг)'),
    (7, 'T3_VR_WIND_DIR',   3, 2, 'Таблица 3: Приращение направления ветра для ВР (аргумент: высота Y)'),
    (8, 'T3_DMK_WIND_SPEED', 2, 1, 'Таблица 3: Скорость среднего ветра для ДМК (аргумент: скорость ветра V0)'),
    (9, 'T3_DMK_WIND_DIR',   3, 1, 'Таблица 3: Приращение направления ветра для ДМК (аргумент: высота Y)')
ON CONFLICT (id) DO UPDATE SET 
    code = EXCLUDED.code, 
    parent_id = EXCLUDED.parent_id, 
    equipment_type_id = EXCLUDED.equipment_type_id, 
    description = EXCLUDED.description;

SELECT setval('calc_correction_types_seq', (SELECT max(id) FROM public.calc_correction_types));


-- 2.3 НОРМАЛИЗАЦИЯ: Таблица заголовков столбцов calc_correction_headers
-- Хранит числовые значения аргументов столбцов для каждого типа таблицы
CREATE SEQUENCE IF NOT EXISTS calc_correction_headers_seq;
CREATE TABLE IF NOT EXISTS public.calc_correction_headers (
    id integer PRIMARY KEY DEFAULT nextval('calc_correction_headers_seq'),
    type_id integer NOT NULL REFERENCES public.calc_correction_types(id) ON DELETE CASCADE,
    col_index integer NOT NULL,
    header_value integer NOT NULL,
    CONSTRAINT uq_calc_correction_headers UNIQUE (type_id, col_index)
);

COMMENT ON TABLE public.calc_correction_headers IS 'Нормализованная таблица заголовков столбцов расчетных матриц поправок';
COMMENT ON COLUMN public.calc_correction_headers.type_id IS 'Ссылка на тип таблицы (calc_correction_types)';
COMMENT ON COLUMN public.calc_correction_headers.col_index IS 'Порядковый номер столбца (1-based индекс в массиве поправок)';
COMMENT ON COLUMN public.calc_correction_headers.header_value IS 'Числовой аргумент в заголовке столбца (градусы, м/с, метры сноса)';

-- Очистка и наполнение заголовков с исправлением опечатки (8, 9 вместо 8, 8)
TRUNCATE TABLE public.calc_correction_headers RESTART IDENTITY;

-- Заголовки для Таблицы 2 (Отрицательные температуры, type_id = 4): 1..10, 20..50
-- ИСПРАВЛЕНА ОПЕЧАТКА: 8, 9 (столбцы 8 и 9), а не 8, 8
INSERT INTO public.calc_correction_headers (type_id, col_index, header_value) VALUES
    (4,  1,  1), (4,  2,  2), (4,  3,  3), (4,  4,  4), (4,  5,  5),
    (4,  6,  6), (4,  7,  7), (4,  8,  8), (4,  9,  9), (4, 10, 10),
    (4, 11, 20), (4, 12, 30), (4, 13, 40), (4, 14, 50);

-- Заголовки для Таблицы 2 (Положительные температуры, type_id = 5): 1..10, 20, 30
INSERT INTO public.calc_correction_headers (type_id, col_index, header_value) VALUES
    (5,  1,  1), (5,  2,  2), (5,  3,  3), (5,  4,  4), (5,  5,  5),
    (5,  6,  6), (5,  7,  7), (5,  8,  8), (5,  9,  9), (5, 10, 10),
    (5, 11, 20), (5, 12, 30);

-- Заголовки для Таблицы 3 (ВР, Скорость среднего ветра, type_id = 6): 40..150 м с шагом 10
INSERT INTO public.calc_correction_headers (type_id, col_index, header_value) VALUES
    (6,  1,  40), (6,  2,  50), (6,  3,  60), (6,  4,  70),
    (6,  5,  80), (6,  6,  90), (6,  7, 100), (6,  8, 110),
    (6,  9, 120), (6, 10, 130), (6, 11, 140), (6, 12, 150);

-- Заголовки для Таблицы 3 (ДМК, Скорость среднего ветра, type_id = 8): 3..15 м/с
INSERT INTO public.calc_correction_headers (type_id, col_index, header_value) VALUES
    (8,  1,  3), (8,  2,  4), (8,  3,  5), (8,  4,  6),
    (8,  5,  7), (8,  6,  8), (8,  7,  9), (8,  8, 10),
    (8,  9, 11), (8, 10, 12), (8, 11, 13), (8, 12, 14), (8, 13, 15);


-- 2.4 Универсальная матрица поправок calc_correction для всех высот 200..4000 м
CREATE SEQUENCE IF NOT EXISTS calc_correction_seq;
CREATE TABLE IF NOT EXISTS public.calc_correction (
    id integer PRIMARY KEY DEFAULT nextval('calc_correction_seq'),
    height_id integer NOT NULL REFERENCES public.calc_correction_heights(id) ON DELETE CASCADE,
    type_id integer NOT NULL REFERENCES public.calc_correction_types(id) ON DELETE CASCADE,
    row_values integer[] NOT NULL,
    dir_shift integer DEFAULT 0,
    CONSTRAINT uq_correction_height_type UNIQUE (height_id, type_id)
);

COMMENT ON TABLE public.calc_correction IS 'Универсальная таблица значений поправок Таблиц 2 и 3 для всех стандартных высот';

-- Наполнение матриц поправок эталонными значениями из ТЗ
TRUNCATE TABLE public.calc_correction RESTART IDENTITY;

-- 1) ТАБЛИЦА 2: Отрицательные значения температуры (type_id = 4, числитель дроби)
-- Высоты 200, 400, 800, 1200, 1600, 2000, 2400, 3000, 4000 м
INSERT INTO public.calc_correction (height_id, type_id, row_values) VALUES
    (1, 4, ARRAY[-1, -2, -3, -4, -5, -6, -7, -8, -8,  -9, -20, -29, -39, -49]), -- 200 м
    (2, 4, ARRAY[-1, -2, -3, -4, -5, -6, -6, -7, -8,  -9, -19, -29, -38, -48]), -- 400 м
    (3, 4, ARRAY[-1, -2, -3, -4, -5, -6, -6, -7, -7,  -8, -18, -28, -37, -46]), -- 800 м
    (4, 4, ARRAY[-1, -2, -3, -4, -4, -5, -5, -6, -7,  -8, -17, -26, -35, -44]), -- 1200 м
    (5, 4, ARRAY[-1, -2, -3, -3, -4, -4, -5, -6, -7,  -7, -17, -25, -34, -42]), -- 1600 м
    (6, 4, ARRAY[-1, -2, -3, -3, -4, -4, -5, -6, -6,  -7, -16, -24, -32, -40]), -- 2000 м
    (7, 4, ARRAY[-1, -2, -2, -3, -4, -4, -5, -5, -6,  -7, -15, -23, -31, -38]), -- 2400 м
    (8, 4, ARRAY[-1, -2, -2, -3, -4, -4, -4, -5, -5,  -6, -15, -22, -30, -37]), -- 3000 м
    (9, 4, ARRAY[-1, -2, -2, -3, -4, -4, -4, -4, -5,  -6, -14, -20, -27, -34]); -- 4000 м

-- 2) ТАБЛИЦА 2: Положительные значения температуры (type_id = 5, знаменатель дроби)
INSERT INTO public.calc_correction (height_id, type_id, row_values) VALUES
    (1, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 200 м
    (2, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 400 м
    (3, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 800 м
    (4, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 1200 м
    (5, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 1600 м
    (6, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 2000 м
    (7, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 2400 м
    (8, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 3000 м
    (9, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]); -- 4000 м

-- 3) ТАБЛИЦА 3 (ВР): Скорость среднего ветра (type_id = 6) по дальности сноса пуль Dг [40..150] м
INSERT INTO public.calc_correction (height_id, type_id, row_values) VALUES
    (1, 6, ARRAY[3, 4, 5, 6,  7,  7,  8,  9, 10, 11, 12, 12]), -- 200 м
    (2, 6, ARRAY[4, 5, 6, 7,  8,  9, 10, 11, 12, 13, 14, 15]), -- 400 м
    (3, 6, ARRAY[4, 5, 6, 7,  8,  9, 10, 11, 13, 14, 15, 16]), -- 800 м
    (4, 6, ARRAY[4, 5, 7, 8,  8,  9, 11, 12, 13, 15, 15, 16]), -- 1200 м
    (5, 6, ARRAY[4, 6, 7, 8,  9, 10, 11, 13, 14, 15, 17, 17]), -- 1600 м
    (6, 6, ARRAY[4, 6, 7, 8,  9, 10, 11, 13, 14, 16, 17, 18]), -- 2000 м
    (7, 6, ARRAY[4, 6, 8, 9,  9, 10, 12, 14, 15, 16, 18, 19]), -- 2400 м
    (8, 6, ARRAY[5, 6, 8, 9, 10, 11, 12, 14, 15, 17, 18, 19]), -- 3000 м
    (9, 6, ARRAY[5, 6, 8, 9, 10, 11, 12, 14, 16, 18, 19, 20]); -- 4000 м

-- 4) ТАБЛИЦА 3 (ВР): Приращение направления среднего ветра (type_id = 7) в дел. угл.
INSERT INTO public.calc_correction (height_id, type_id, row_values, dir_shift) VALUES
    (1, 7, ARRAY[0], 0), -- 200 м: +0-00
    (2, 7, ARRAY[1], 1), -- 400 м: +1-00
    (3, 7, ARRAY[2], 2), -- 800 м: +2-00
    (4, 7, ARRAY[2], 2), -- 1200 м: +2-00
    (5, 7, ARRAY[3], 3), -- 1600 м: +3-00
    (6, 7, ARRAY[3], 3), -- 2000 м: +3-00
    (7, 7, ARRAY[3], 3), -- 2400 м: +3-00
    (8, 7, ARRAY[4], 4), -- 3000 м: +4-00
    (9, 7, ARRAY[4], 4); -- 4000 м: +4-00

-- 5) ТАБЛИЦА 3 (ДМК): Скорость среднего ветра (type_id = 8) по приземной скорости V0 [3..15] м/с
INSERT INTO public.calc_correction (height_id, type_id, row_values) VALUES
    (1, 8, ARRAY[4,  6,  8,  9, 10, 12, 14, 15, 16, 18, 20, 21, 22]), -- 200 м
    (2, 8, ARRAY[5,  7, 10, 11, 12, 14, 17, 18, 20, 22, 23, 25, 27]), -- 400 м
    (3, 8, ARRAY[5,  8, 10, 11, 13, 15, 18, 19, 21, 23, 25, 27, 28]), -- 800 м
    (4, 8, ARRAY[5,  8, 11, 12, 13, 16, 19, 20, 23, 24, 26, 28, 30]), -- 1200 м
    (5, 8, ARRAY[6,  8, 11, 13, 14, 17, 20, 21, 23, 25, 27, 29, 32]), -- 1600 м
    (6, 8, ARRAY[6,  9, 11, 13, 14, 17, 20, 21, 24, 26, 28, 30, 32]), -- 2000 м
    (7, 8, ARRAY[6,  9, 12, 14, 15, 18, 21, 22, 25, 27, 29, 32, 34]), -- 2400 м
    (8, 8, ARRAY[6,  9, 12, 14, 15, 18, 21, 23, 25, 28, 30, 32, 36]), -- 3000 м
    (9, 8, ARRAY[6, 10, 12, 14, 16, 19, 22, 24, 26, 29, 32, 34, 36]); -- 4000 м

-- 6) ТАБЛИЦА 3 (ДМК): Приращение направления среднего ветра (type_id = 9) в дел. угл.
INSERT INTO public.calc_correction (height_id, type_id, row_values, dir_shift) VALUES
    (1, 9, ARRAY[1], 1), -- 200 м: +1-00
    (2, 9, ARRAY[2], 2), -- 400 м: +2-00
    (3, 9, ARRAY[3], 3), -- 800 м: +3-00
    (4, 9, ARRAY[3], 3), -- 1200 м: +3-00
    (5, 9, ARRAY[4], 4), -- 1600 м: +4-00
    (6, 9, ARRAY[4], 4), -- 2000 м: +4-00
    (7, 9, ARRAY[4], 4), -- 2400 м: +4-00
    (8, 9, ARRAY[5], 5), -- 3000 м: +5-00
    (9, 9, ARRAY[5], 5); -- 4000 м: +5-00


-- 3. Результирующая таблица для наглядного вывода и снятия скриншотов

CREATE SEQUENCE IF NOT EXISTS meteo_bulletin_results_id_seq;
CREATE TABLE IF NOT EXISTS public.meteo_bulletin_results (
    id integer PRIMARY KEY DEFAULT nextval('meteo_bulletin_results_id_seq'),
    equipment_id integer NOT NULL,
    equipment_name character varying(50) NOT NULL,
    bulletin_header character varying(100) NOT NULL,
    height_code character varying(10) NOT NULL,
    height_m integer NOT NULL,
    temp_correction character varying(10) NOT NULL,
    wind_direction character varying(10) NOT NULL,
    wind_speed character varying(10) NOT NULL,
    bulletin_line character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp()
);

COMMENT ON TABLE public.meteo_bulletin_results IS 'Таблица результатов расчета приближенного метеобюллетеня (Метео-11)';


-- 4. Хранимая процедура расчета метеобюллетеня sp_calc_meteo_approximate

CREATE OR REPLACE PROCEDURE public.sp_calc_meteo_approximate(
    IN par_params input_params_type,
    IN par_equipment_type_id integer
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    -- Проверенные параметры
    var_validated_params  input_params_type;
    var_equipment_name    VARCHAR(50);
    
    -- Заголовок бюллетеня
    var_ddchm             TEXT;
    var_vvvv              TEXT;
    var_bbb               TEXT;
    var_tt_header         TEXT;
    var_full_header       TEXT;
    
    -- Промежуточные величины для заголовка
    var_delta_p           NUMERIC;
    var_delta_tv          NUMERIC;
    var_t0                NUMERIC;
    var_delta_t0_mp       NUMERIC;
    var_delta_t0_rounded  INT;
    
    -- Идентификаторы срезов типов таблиц
    var_t2_neg_id         INT;
    var_t2_pos_id         INT;
    var_t3_vr_spd_id      INT;
    var_t3_vr_dir_id      INT;
    var_t3_dmk_spd_id     INT;
    var_t3_dmk_dir_id     INT;

    -- Переменные цикла по высотам
    rec_h                 RECORD;
    var_h_code            VARCHAR(10);
    var_t2_type_id        INT;
    var_abs_dt            INT;
    var_tens              INT;
    var_units             INT;
    var_corr_tens         INT;
    var_corr_units        INT;
    var_sum_t2            INT;
    var_tt_str            VARCHAR(10);
    
    var_cc_val            INT;
    var_cc_str            VARCHAR(10);
    var_delta_alpha       INT;
    var_hh_val            INT;
    var_hh_str            VARCHAR(10);
    
    var_line_str          VARCHAR(50);
    var_output_text       TEXT := '';
BEGIN
    -- 1. Определение типа прибора
    IF par_equipment_type_id = 1 THEN
        var_equipment_name := 'ДМК (Десантный метеокомплект)';
    ELSIF par_equipment_type_id = 2 THEN
        var_equipment_name := 'ВР (Ветровое ружье)';
    ELSE
        RAISE EXCEPTION 'Неизвестный код оборудования: %. Допустимо: 1 (ДМК) или 2 (ВР)', par_equipment_type_id;
    END IF;

    -- 2. Валидация входных данных через штатную функцию
    var_validated_params := public.fn_check_input_params(par_params);

    -- 3. Определение динамических ID типов таблиц
    SELECT coalesce((SELECT id FROM calc_correction_types WHERE code = 'T2_TEMP_NEG'), 4) INTO var_t2_neg_id;
    SELECT coalesce((SELECT id FROM calc_correction_types WHERE code = 'T2_TEMP_POS'), 5) INTO var_t2_pos_id;
    SELECT coalesce((SELECT id FROM calc_correction_types WHERE code = 'T3_VR_WIND_SPEED'), 6) INTO var_t3_vr_spd_id;
    SELECT coalesce((SELECT id FROM calc_correction_types WHERE code = 'T3_VR_WIND_DIR'), 7) INTO var_t3_vr_dir_id;
    SELECT coalesce((SELECT id FROM calc_correction_types WHERE code = 'T3_DMK_WIND_SPEED'), 8) INTO var_t3_dmk_spd_id;
    SELECT coalesce((SELECT id FROM calc_correction_types WHERE code = 'T3_DMK_WIND_DIR'), 9) INTO var_t3_dmk_dir_id;

    -- 4. Расчет элементов заголовка бюллетеня
    -- 4.1 ДДЧЧМ (число, часы, десятки минут окончания измерения)
    var_ddchm := public.fn_calc_header_period(clock_timestamp());

    -- 4.2 ВВВВ (высота расположения метеопоста, 4 знака)
    var_vvvv := lpad(round(par_params.height)::int::text, 4, '0');

    -- 4.3 БББ (отклонение наземного давления Delta H0 = H0 - 750)
    var_delta_p := round(public.fn_calc_header_pressure(par_params.pressure));
    IF var_delta_p < 0 THEN
        var_bbb := '5' || lpad(abs(var_delta_p::int)::text, 2, '0');
    ELSE
        var_bbb := lpad(var_delta_p::int::text, 3, '0');
    END IF;

    -- 4.4 ТТ заголовка (Delta T0 = t0 + DeltaTv - 15.9)
    var_delta_tv := public.fn_calc_temperature_interpolation(par_params.temperature);
    var_t0 := par_params.temperature + var_delta_tv;
    var_delta_t0_mp := var_t0 - 15.9;
    var_delta_t0_rounded := round(var_delta_t0_mp)::int;

    IF var_delta_t0_rounded < 0 THEN
        var_tt_header := lpad((abs(var_delta_t0_rounded) + 50)::text, 2, '0');
    ELSE
        var_tt_header := lpad(var_delta_t0_rounded::text, 2, '0');
    END IF;

    -- Полный заголовок бюллетеня
    var_full_header := 'МЕТЕО11 ' || var_ddchm || ' ' || var_vvvv || ' ' || var_bbb || var_tt_header;

    -- Очищаем предыдущие результаты для данного прибора
    DELETE FROM public.meteo_bulletin_results WHERE equipment_id = par_equipment_type_id;

    -- Шапка псевдографического отчета для RAISE NOTICE
    var_output_text := chr(10) ||
        '=====================================================================' || chr(10) ||
        '      БЮЛЛЕТЕНЬ «МЕТЕО-11 ПРИБЛИЖЕННЫЙ» (АРТИЛЛЕРИЙСКИЙ РАСЧЕТ)       ' || chr(10) ||
        '=====================================================================' || chr(10) ||
        ' Прибор: ' || var_equipment_name || chr(10) ||
        ' Исходные данные: H=' || par_params.height || ' м, P=' || par_params.pressure || ' мм рт.ст., ' ||
        'T=' || par_params.temperature || '°C, Направление ветра=' || par_params.wind_direction || ' д.у.' ||
        CASE WHEN par_equipment_type_id = 1 THEN ', Скорость ветра=' || par_params.wind_speed || ' м/с'
             ELSE ', Снос пуль Dг=' || par_params.bullet_demolition_range || ' м' END || chr(10) ||
        ' Заголовок: ' || var_full_header || ' (ДДЧЧМ=' || var_ddchm || ', ВВВВ=' || var_vvvv ||
        ', БББ=' || var_bbb || ', ТТ=' || var_tt_header || ')' || chr(10) ||
        '---------------------------------------------------------------------' || chr(10) ||
        '  H (м)  | Код H |  TT (поправка T) | HH (напр. ветра) | CC (скор. ветра) ' || chr(10) ||
        '---------------------------------------------------------------------' || chr(10);

    -- 5. Цикл по всем 9 стандартным высотам бюллетеня
    FOR rec_h IN 
        SELECT id, height 
        FROM public.calc_correction_heights 
        ORDER BY height ASC
    LOOP
        -- Код высоты бюллетеня: 02, 04, 08, 12, 16, 20, 24, 30, 40
        var_h_code := lpad((rec_h.height / 100)::text, 2, '0');

        -- 5.1 Расчет поправки температуры TT по Таблице 2 (декомпозиция десятков и единиц)
        var_abs_dt := abs(var_delta_t0_rounded);
        var_tens := (var_abs_dt / 10) * 10;
        var_units := var_abs_dt % 10;
        
        IF var_delta_t0_rounded < 0 THEN
            var_t2_type_id := var_t2_neg_id; -- Отрицательные (числитель)
        ELSE
            var_t2_type_id := var_t2_pos_id; -- Положительные (знаменатель)
        END IF;

        var_corr_tens := 0;
        IF var_tens > 0 THEN
            SELECT c.row_values[h.col_index]
            INTO var_corr_tens
            FROM public.calc_correction c
            JOIN public.calc_correction_headers h ON h.type_id = c.type_id
            WHERE c.height_id = rec_h.id 
              AND c.type_id = var_t2_type_id 
              AND h.header_value = var_tens;
        END IF;

        var_corr_units := 0;
        IF var_units > 0 THEN
            SELECT c.row_values[h.col_index]
            INTO var_corr_units
            FROM public.calc_correction c
            JOIN public.calc_correction_headers h ON h.type_id = c.type_id
            WHERE c.height_id = rec_h.id 
              AND c.type_id = var_t2_type_id 
              AND h.header_value = var_units;
        END IF;

        var_sum_t2 := coalesce(var_corr_tens, 0) + coalesce(var_corr_units, 0);

        IF var_sum_t2 < 0 THEN
            -- Для отрицательных величин к модулю прибавляется 50 (например, -12 -> 62)
            var_tt_str := lpad((abs(var_sum_t2) + 50)::text, 2, '0');
        ELSE
            var_tt_str := lpad(var_sum_t2::text, 2, '0');
        END IF;

        -- 5.2 Определение скорости (CC) и направления (HH) среднего ветра по Таблице 3
        IF par_equipment_type_id = 1 THEN
            -- Прибор ДМК
            IF par_params.wind_speed < 3 THEN
                -- Если V0 < 3 м/с, то скорость и направление ветра = 0
                var_cc_str := '00';
                var_hh_str := '00';
            ELSE
                DECLARE
                    var_v0 INT := round(par_params.wind_speed)::int;
                BEGIN
                    IF var_v0 > 15 THEN var_v0 := 15; END IF;
                    IF var_v0 < 3 THEN var_v0 := 3; END IF;

                    -- Скорость ветра по Таблице 3 (ДМК)
                    SELECT c.row_values[h.col_index]
                    INTO var_cc_val
                    FROM public.calc_correction c
                    JOIN public.calc_correction_headers h ON h.type_id = c.type_id
                    WHERE c.height_id = rec_h.id 
                      AND c.type_id = var_t3_dmk_spd_id 
                      AND h.header_value = var_v0;

                    var_cc_str := lpad(var_cc_val::text, 2, '0');

                    -- Приращение направления ветра Delta alpha_WY
                    SELECT coalesce(c.dir_shift, c.row_values[1], 0)
                    INTO var_delta_alpha
                    FROM public.calc_correction c
                    WHERE c.height_id = rec_h.id AND c.type_id = var_t3_dmk_dir_id;

                    -- Направление ветра: (alpha_V0 + Delta alpha) mod 60
                    var_hh_val := (round(par_params.wind_direction)::int + var_delta_alpha) % 60;
                    IF var_hh_val < 0 THEN var_hh_val := (var_hh_val + 60) % 60; END IF;
                    var_hh_str := lpad(var_hh_val::text, 2, '0');
                END;
            END IF;

        ELSIF par_equipment_type_id = 2 THEN
            -- Прибор ВР (Ветровое ружье)
            IF par_params.bullet_demolition_range < 40 THEN
                -- Если Dг < 40 м, то скорость и направление ветра = 0
                var_cc_str := '00';
                var_hh_str := '00';
            ELSE
                DECLARE
                    var_dg INT := (round(par_params.bullet_demolition_range / 10.0) * 10)::int;
                BEGIN
                    IF var_dg > 150 THEN var_dg := 150; END IF;
                    IF var_dg < 40 THEN var_dg := 40; END IF;

                    -- Скорость ветра по Таблице 3 (ВР)
                    SELECT c.row_values[h.col_index]
                    INTO var_cc_val
                    FROM public.calc_correction c
                    JOIN public.calc_correction_headers h ON h.type_id = c.type_id
                    WHERE c.height_id = rec_h.id 
                      AND c.type_id = var_t3_vr_spd_id 
                      AND h.header_value = var_dg;

                    var_cc_str := lpad(var_cc_val::text, 2, '0');

                    -- Приращение направления ветра Delta alpha_WY
                    SELECT coalesce(c.dir_shift, c.row_values[1], 0)
                    INTO var_delta_alpha
                    FROM public.calc_correction c
                    WHERE c.height_id = rec_h.id AND c.type_id = var_t3_vr_dir_id;

                    -- Направление ветра: (alpha_V0 + Delta alpha) mod 60
                    var_hh_val := (round(par_params.wind_direction)::int + var_delta_alpha) % 60;
                    IF var_hh_val < 0 THEN var_hh_val := (var_hh_val + 60) % 60; END IF;
                    var_hh_str := lpad(var_hh_val::text, 2, '0');
                END;
            END IF;
        END IF;

        -- 5.3 Формирование строки бюллетеня: HH TT HH CC
        var_line_str := var_h_code || ' ' || var_tt_str || ' ' || var_hh_str || ' ' || var_cc_str;

        -- Сохранение во вспомогательную таблицу результатов
        INSERT INTO public.meteo_bulletin_results (
            equipment_id, equipment_name, bulletin_header, height_code, height_m,
            temp_correction, wind_direction, wind_speed, bulletin_line
        ) VALUES (
            par_equipment_type_id, var_equipment_name, var_full_header, var_h_code, rec_h.height,
            var_tt_str, var_hh_str, var_cc_str, var_line_str
        );

        -- Строка отчета для консоли
        var_output_text := var_output_text || 
            '  ' || lpad(rec_h.height::text, 5, ' ') || '  |  ' || var_h_code || '   |        ' ||
            var_tt_str || '        |        ' || var_hh_str || '        |        ' || var_cc_str || '        ' || chr(10);
    END LOOP;

    -- Подвал отчета с полным текстом бюллетеня
    var_output_text := var_output_text ||
        '---------------------------------------------------------------------' || chr(10) ||
        ' Итоговый текст бюллетеня: ' || var_full_header || chr(10) ||
        (SELECT string_agg(bulletin_line, ' ') FROM (
            SELECT bulletin_line FROM public.meteo_bulletin_results 
            WHERE equipment_id = par_equipment_type_id 
            ORDER BY height_m
        ) s) || chr(10) ||
        '=====================================================================' || chr(10);

    -- Вывод в лог / консоль / Messages
    RAISE NOTICE '%', var_output_text;
END;
$procedure$;

-- Перегруженная версия процедуры с приемом типа оборудования как VARCHAR ('1'/'DMK'/'ДМК' или '2'/'VR'/'ВР')
CREATE OR REPLACE PROCEDURE public.sp_calc_meteo_approximate(
    IN par_params input_params_type,
    IN par_equipment_type character varying
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    var_eq_id INT;
BEGIN
    IF upper(trim(par_equipment_type)) IN ('1', 'DMK', 'ДМК') THEN
        var_eq_id := 1;
    ELSIF upper(trim(par_equipment_type)) IN ('2', 'VR', 'ВР') THEN
        var_eq_id := 2;
    ELSE
        RAISE EXCEPTION 'Неизвестный тип оборудования: %. Используйте 1 (ДМК) или 2 (ВР)', par_equipment_type;
    END IF;

    CALL public.sp_calc_meteo_approximate(par_params, var_eq_id);
END;
$procedure$;
