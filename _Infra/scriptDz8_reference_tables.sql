-- scriptDz8_reference_tables.sql
-- Справочные структуры для хранения Таблицы 2 и Таблицы 3 (Метео-11)
-- для расчета поправок оборудования ВР (ветровое ружье) и ДМК

DO $do$
BEGIN
    -- 1. Удаление старых объектов (в порядке обратных зависимостей)
    DROP TABLE IF EXISTS calc_correction CASCADE;
    DROP TABLE IF EXISTS calc_correction_types CASCADE;
    DROP TABLE IF EXISTS calc_correction_heights CASCADE;
    DROP TABLE IF EXISTS device_specs CASCADE;

    -- 2. Таблица стандартных высот (Y = 200, 400, 800, 1200, 1600, 2000, 2400, 3000, 4000 м)
    CREATE SEQUENCE IF NOT EXISTS calc_correction_height_seq;
    CREATE TABLE calc_correction_heights (
        id     INT PRIMARY KEY DEFAULT nextval('calc_correction_height_seq'),
        height INT NOT NULL UNIQUE
    );

    COMMENT ON TABLE calc_correction_heights IS 'Справочник стандартных высот зондирования атмосферы (Y, м)';
    COMMENT ON COLUMN calc_correction_heights.id IS 'Уникальный идентификатор высоты';
    COMMENT ON COLUMN calc_correction_heights.height IS 'Стандартная высота слоя в метрах';

    INSERT INTO calc_correction_heights (id, height) VALUES
        (1, 200),
        (2, 400),
        (3, 800),
        (4, 1200),
        (5, 1600),
        (6, 2000),
        (7, 2400),
        (8, 3000),
        (9, 4000);

    -- 3. Справочник типов расчетных таблиц корректировок с привязкой к оборудованию
    CREATE SEQUENCE IF NOT EXISTS calc_correction_types_seq;
    CREATE TABLE calc_correction_types (
        id                     INT PRIMARY KEY DEFAULT nextval('calc_correction_types_seq'),
        code                   VARCHAR(50) NOT NULL UNIQUE,
        parent_id              INT REFERENCES calc_correction_types(id) ON DELETE CASCADE,
        equipment_type_id      INT REFERENCES equipment_types(id) ON DELETE SET NULL,
        description            TEXT NOT NULL,
        header_values          INT[]
    );

    COMMENT ON TABLE calc_correction_types IS 'Иерархический справочник таблиц корректировок и заголовков входных аргументов';
    COMMENT ON COLUMN calc_correction_types.id IS 'Уникальный код типа таблицы';
    COMMENT ON COLUMN calc_correction_types.code IS 'Уникальный символьный код типа таблицы';
    COMMENT ON COLUMN calc_correction_types.parent_id IS 'Ссылка на родительскую таблицу верхнего уровня';
    COMMENT ON COLUMN calc_correction_types.equipment_type_id IS 'Ссылка на оборудование (1 - ДМК, 2 - ВР, NULL - универсально)';
    COMMENT ON COLUMN calc_correction_types.description IS 'Подробное описание назначения таблицы';
    COMMENT ON COLUMN calc_correction_types.header_values IS 'Массив значений аргументов в заголовке таблицы (градусы, м/с, метры)';

    -- 3.1 Родительские типы
    INSERT INTO calc_correction_types (id, code, parent_id, equipment_type_id, description, header_values) VALUES
        (1, 'TABLE_2', NULL, NULL, 'Таблица 2: Средние отклонения температуры воздуха (Метео-11)',
            ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50]),
        (2, 'TABLE_3_WIND_SPEED', NULL, NULL, 'Таблица 3: Скорость среднего ветра (Wy)', NULL),
        (3, 'TABLE_3_WIND_DIR',   NULL, NULL, 'Таблица 3: Приращение направления среднего ветра (delta_alpha_Wy)', NULL);

    -- 3.2 Дочерние типы для конкретных срезов и типов оборудования
    INSERT INTO calc_correction_types (id, code, parent_id, equipment_type_id, description, header_values) VALUES
        -- Таблица 2: срез положительных и отрицательных температур
        (4, 'T2_TEMP_NEG', 1, NULL, 'Таблица 2: Отклонения температуры (отрицательные значения, числитель)',
            ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50]),
        (5, 'T2_TEMP_POS', 1, NULL, 'Таблица 2: Отклонения температуры (положительные значения, знаменатель)',
            ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]),

        -- Таблица 3 для ВР (Ветровое ружье, equipment_types id = 2) по дальности сноса пуль Dг (40..150 м)
        (6, 'T3_VR_WIND_SPEED', 2, 2, 'Таблица 3: Скорость среднего ветра для ВР (аргумент: дальность сноса пуль, м)',
            ARRAY[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]),
        (7, 'T3_VR_WIND_DIR',   3, 2, 'Таблица 3: Приращение направления ветра для ВР (аргумент: высота Y, дел. угл.)',
            NULL),

        -- Таблица 3 для ДМК (Десантный метеокомплект, equipment_types id = 1) по скорости приземного ветра V0 (3..15 м/с)
        (8, 'T3_DMK_WIND_SPEED', 2, 1, 'Таблица 3: Скорость среднего ветра для ДМК (аргумент: скорость ветра V0, м/с)',
            ARRAY[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
        (9, 'T3_DMK_WIND_DIR',   3, 1, 'Таблица 3: Приращение направления ветра для ДМК (аргумент: высота Y, дел. угл.)',
            NULL);

    -- 4. Универсальная таблица значений корректировок
    CREATE SEQUENCE IF NOT EXISTS calc_correction_seq;
    CREATE TABLE calc_correction (
        id         INT PRIMARY KEY DEFAULT nextval('calc_correction_seq'),
        height_id  INT NOT NULL REFERENCES calc_correction_heights(id) ON DELETE CASCADE,
        type_id    INT NOT NULL REFERENCES calc_correction_types(id) ON DELETE CASCADE,
        row_values INT[] NOT NULL,
        dir_shift  INT DEFAULT 0,
        CONSTRAINT uq_correction_height_type UNIQUE (height_id, type_id)
    );

    COMMENT ON TABLE calc_correction IS 'Универсальная таблица матриц значений поправок Таблицы 2 и Таблицы 3';
    COMMENT ON COLUMN calc_correction.id IS 'Уникальный код строки поправки';
    COMMENT ON COLUMN calc_correction.height_id IS 'Ссылка на стандартную высоту';
    COMMENT ON COLUMN calc_correction.type_id IS 'Ссылка на тип таблицы/среза';
    COMMENT ON COLUMN calc_correction.row_values IS 'Массив значений поправок, соответствующих элементам header_values';
    COMMENT ON COLUMN calc_correction.dir_shift IS 'Поправка направления ветра в делениях угломера (дел. угл.)';

    -- 5. Заполнение матрицы поправок реальными данными из ТЗ (Таблицы 2 и 3 Метео-11)

    -- 5.1 ТАБЛИЦА 2: Отрицательные значения температуры (type_id = 4) для всех высот 200..4000 м
    INSERT INTO calc_correction (height_id, type_id, row_values) VALUES
        (1, 4, ARRAY[-1, -2, -3, -4, -5, -6, -7, -8, -8,  -9, -20, -29, -39, -49]), -- 200 м
        (2, 4, ARRAY[-1, -2, -3, -4, -5, -6, -6, -7, -8,  -9, -19, -29, -38, -48]), -- 400 м
        (3, 4, ARRAY[-1, -2, -3, -4, -5, -6, -6, -7, -7,  -8, -18, -28, -37, -46]), -- 800 м
        (4, 4, ARRAY[-1, -2, -3, -4, -4, -5, -5, -6, -7,  -8, -17, -26, -35, -44]), -- 1200 м
        (5, 4, ARRAY[-1, -2, -3, -3, -4, -4, -5, -6, -7,  -7, -17, -25, -34, -42]), -- 1600 м
        (6, 4, ARRAY[-1, -2, -3, -3, -4, -4, -5, -6, -6,  -7, -16, -24, -32, -40]), -- 2000 м
        (7, 4, ARRAY[-1, -2, -2, -3, -4, -4, -5, -5, -6,  -7, -15, -23, -31, -38]), -- 2400 м
        (8, 4, ARRAY[-1, -2, -2, -3, -4, -4, -4, -5, -5,  -6, -15, -22, -30, -37]), -- 3000 м
        (9, 4, ARRAY[-1, -2, -2, -3, -4, -4, -4, -4, -5,  -6, -14, -20, -27, -34]); -- 4000 м

    -- 5.2 ТАБЛИЦА 2: Положительные значения температуры (type_id = 5) для всех высот 200..4000 м
    INSERT INTO calc_correction (height_id, type_id, row_values) VALUES
        (1, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 200 м
        (2, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 400 м
        (3, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 800 м
        (4, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 1200 м
        (5, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 1600 м
        (6, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 2000 м
        (7, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 2400 м
        (8, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 3000 м
        (9, 5, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]); -- 4000 м

    -- 5.3 ТАБЛИЦА 3 (ВР): Скорость среднего ветра (type_id = 6) по дальности сноса пуль Dг [40..150] м
    INSERT INTO calc_correction (height_id, type_id, row_values) VALUES
        (1, 6, ARRAY[3, 4, 5, 6,  7,  7,  8,  9, 10, 11, 12, 12]), -- 200 м
        (2, 6, ARRAY[4, 5, 6, 7,  8,  9, 10, 11, 12, 13, 14, 15]), -- 400 м
        (3, 6, ARRAY[4, 5, 6, 7,  8,  9, 10, 11, 13, 14, 15, 16]), -- 800 м
        (4, 6, ARRAY[4, 5, 7, 8,  8,  9, 11, 12, 13, 15, 15, 16]), -- 1200 м
        (5, 6, ARRAY[4, 6, 7, 8,  9, 10, 11, 13, 14, 15, 17, 17]), -- 1600 м
        (6, 6, ARRAY[4, 6, 7, 8,  9, 10, 11, 13, 14, 16, 17, 18]), -- 2000 м
        (7, 6, ARRAY[4, 6, 8, 9,  9, 10, 12, 14, 15, 16, 18, 19]), -- 2400 м
        (8, 6, ARRAY[5, 6, 8, 9, 10, 11, 12, 14, 15, 17, 18, 19]), -- 3000 м
        (9, 6, ARRAY[5, 6, 8, 9, 10, 11, 12, 14, 16, 18, 19, 20]); -- 4000 м

    -- 5.4 ТАБЛИЦА 3 (ВР): Приращение направления ветра (type_id = 7) в делениях угломера
    INSERT INTO calc_correction (height_id, type_id, row_values, dir_shift) VALUES
        (1, 7, ARRAY[0], 0), -- 200 м: +0-00
        (2, 7, ARRAY[1], 1), -- 400 м: +1-00
        (3, 7, ARRAY[2], 2), -- 800 м: +2-00
        (4, 7, ARRAY[2], 2), -- 1200 м: +2-00
        (5, 7, ARRAY[3], 3), -- 1600 м: +3-00
        (6, 7, ARRAY[3], 3), -- 2000 м: +3-00
        (7, 7, ARRAY[3], 3), -- 2400 м: +3-00
        (8, 7, ARRAY[4], 4), -- 3000 м: +4-00
        (9, 7, ARRAY[4], 4); -- 4000 м: +4-00

    -- 5.5 ТАБЛИЦА 3 (ДМК): Скорость среднего ветра (type_id = 8) по скорости приземного ветра V0 [3..15] м/с
    INSERT INTO calc_correction (height_id, type_id, row_values) VALUES
        (1, 8, ARRAY[4,  6,  8,  9, 10, 12, 14, 15, 16, 18, 20, 21, 22]), -- 200 м
        (2, 8, ARRAY[5,  7, 10, 11, 12, 14, 17, 18, 20, 22, 23, 25, 27]), -- 400 м
        (3, 8, ARRAY[5,  8, 10, 11, 13, 15, 18, 19, 21, 23, 25, 27, 28]), -- 800 м
        (4, 8, ARRAY[5,  8, 11, 12, 13, 16, 19, 20, 23, 24, 26, 28, 30]), -- 1200 м
        (5, 8, ARRAY[6,  8, 11, 13, 14, 17, 20, 21, 23, 25, 27, 29, 32]), -- 1600 м
        (6, 8, ARRAY[6,  9, 11, 13, 14, 17, 20, 21, 24, 26, 28, 30, 32]), -- 2000 м
        (7, 8, ARRAY[6,  9, 12, 14, 15, 18, 21, 22, 25, 27, 29, 32, 34]), -- 2400 м
        (8, 8, ARRAY[6,  9, 12, 14, 15, 18, 21, 23, 25, 28, 30, 32, 36]), -- 3000 м
        (9, 8, ARRAY[6, 10, 12, 14, 16, 19, 22, 24, 26, 29, 32, 34, 36]); -- 4000 м

    -- 5.6 ТАБЛИЦА 3 (ДМК): Приращение направления ветра (type_id = 9) в делениях угломера
    INSERT INTO calc_correction (height_id, type_id, row_values, dir_shift) VALUES
        (1, 9, ARRAY[1], 1), -- 200 м: +1-00
        (2, 9, ARRAY[2], 2), -- 400 м: +2-00
        (3, 9, ARRAY[3], 3), -- 800 м: +3-00
        (4, 9, ARRAY[3], 3), -- 1200 м: +3-00
        (5, 9, ARRAY[4], 4), -- 1600 м: +4-00
        (6, 9, ARRAY[4], 4), -- 2000 м: +4-00
        (7, 9, ARRAY[4], 4), -- 2400 м: +4-00
        (8, 9, ARRAY[5], 5), -- 3000 м: +5-00
        (9, 9, ARRAY[5], 5); -- 4000 м: +5-00

    -- 6. Дополнительная вспомогательная таблица технических характеристик оборудования
    -- (добавляет изюминку из PR одногруппника, связывая с существующими таблицами)
    CREATE TABLE device_specs (
        id                INT PRIMARY KEY,
        equipment_type_id INT NOT NULL REFERENCES equipment_types(id) ON DELETE CASCADE,
        parameter_type_id INT NOT NULL REFERENCES parameter_types(id) ON DELETE CASCADE,
        min_value         NUMERIC(10,2),
        max_value         NUMERIC(10,2),
        accuracy          NUMERIC(10,2),
        unit_id           INT REFERENCES units(id) ON DELETE SET NULL,
        description       TEXT
    );

    COMMENT ON TABLE device_specs IS 'Паспортные технические характеристики и погрешности приборов ВР и ДМК';
    COMMENT ON COLUMN device_specs.id IS 'Уникальный номер записи характеристики';
    COMMENT ON COLUMN device_specs.equipment_type_id IS 'Ссылка на тип оборудования';
    COMMENT ON COLUMN device_specs.parameter_type_id IS 'Ссылка на тип параметра';
    COMMENT ON COLUMN device_specs.min_value IS 'Нижняя граница диапазона измерений';
    COMMENT ON COLUMN device_specs.max_value IS 'Верхняя граница диапазона измерений';
    COMMENT ON COLUMN device_specs.accuracy IS 'Паспортная точность (погрешность)';

    INSERT INTO device_specs (id, equipment_type_id, parameter_type_id, min_value, max_value, accuracy, unit_id, description) VALUES
        (1,  1, 1, -100.0, 5000.0, 1.0, 1, 'ДМК: Высота метеопоста [-100..5000] м, точность 1 м'),
        (2,  1, 2,  -58.0,   58.0, 0.1, 2, 'ДМК: Температура воздуха [-58..58] °C, точность 0.1 °C'),
        (3,  1, 3,  500.0,  900.0, 1.0, 3, 'ДМК: Атмосферное давление [500..900] мм рт. ст., точность 1 мм рт. ст.'),
        (4,  1, 4,    0.0,   59.0, 1.0, 4, 'ДМК: Направление ветра [0..59] дел. угл., точность 1 дел. угл.'),
        (5,  1, 5,    0.0,   15.0, 1.0, 5, 'ДМК: Скорость приземного ветра [0..15] м/с, точность 1 м/с'),
        (6,  2, 1, -100.0, 5000.0, 1.0, 1, 'ВР: Высота метеопоста [-100..5000] м, точность 1 м'),
        (7,  2, 2,  -58.0,   58.0, 0.1, 2, 'ВР: Температура воздуха [-58..58] °C, точность 0.1 °C'),
        (8,  2, 3,  500.0,  900.0, 1.0, 3, 'ВР: Атмосферное давление [500..900] мм рт. ст., точность 1 мм рт. ст.'),
        (9,  2, 4,    0.0,   59.0, 1.0, 4, 'ВР: Направление ветра [0..59] дел. угл., точность 1 дел. угл.'),
        (10, 2, 6,    0.0,  150.0, 1.0, 1, 'ВР: Дальность сноса ветровых пуль [0..150] м, точность 1 м');

END;
$do$;
