-- ДЗ 5: Миграционный PL/pgSQL скрипт

DO $$
BEGIN
    -- 1. Транзакция: создание структуры таблиц и счетчиков
    BEGIN
        CREATE SEQUENCE IF NOT EXISTS seq_base_units_id;
        CREATE TABLE IF NOT EXISTS base_units (
            id INT DEFAULT nextval('seq_base_units_id'),
            code VARCHAR(20) NOT NULL,
            name VARCHAR(100) NOT NULL
        );

        CREATE SEQUENCE IF NOT EXISTS seq_units_id;
        CREATE TABLE IF NOT EXISTS units (
            id INT DEFAULT nextval('seq_units_id'),
            code VARCHAR(20) NOT NULL,
            name VARCHAR(100) NOT NULL,
            base_unit_id INT,
            convert_factor NUMERIC(10,4) DEFAULT 1.0
        );

        CREATE SEQUENCE IF NOT EXISTS seq_positions_id;
        CREATE TABLE IF NOT EXISTS positions (
            id INT DEFAULT nextval('seq_positions_id'),
            code VARCHAR(20) NOT NULL,
            name VARCHAR(100) NOT NULL
        );

        CREATE SEQUENCE IF NOT EXISTS seq_employees_id;
        CREATE TABLE IF NOT EXISTS employees (
            id INT DEFAULT nextval('seq_employees_id'),
            code VARCHAR(20) NOT NULL,
            name VARCHAR(150) NOT NULL,
            birthday DATE,
            position_id INT
        );

        CREATE SEQUENCE IF NOT EXISTS seq_equipment_types_id;
        CREATE TABLE IF NOT EXISTS equipment_types (
            id INT DEFAULT nextval('seq_equipment_types_id'),
            code VARCHAR(20) NOT NULL,
            name VARCHAR(100) NOT NULL,
            description TEXT
        );

        CREATE SEQUENCE IF NOT EXISTS seq_parameter_types_id;
        CREATE TABLE IF NOT EXISTS parameter_types (
            id INT DEFAULT nextval('seq_parameter_types_id'),
            code VARCHAR(30) NOT NULL,
            name VARCHAR(100) NOT NULL,
            unit_id INT,
            equipment_type_id INT
        );

        CREATE SEQUENCE IF NOT EXISTS seq_batches_id;
        CREATE TABLE IF NOT EXISTS batches (
            id INT DEFAULT nextval('seq_batches_id'),
            code VARCHAR(30) NOT NULL,
            employee_id INT,
            equipment_type_id INT,
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        );

        CREATE SEQUENCE IF NOT EXISTS seq_parameters_id;
        CREATE TABLE IF NOT EXISTS parameters (
            id INT DEFAULT nextval('seq_parameters_id'),
            code VARCHAR(50) NOT NULL,
            batch_id INT,
            parameter_type_id INT,
            value NUMERIC(10,2) NOT NULL
        );

        -- Таблица 1: Расчет температуры (виртуальная поправка)
        CREATE SEQUENCE IF NOT EXISTS seq_temperature_corrections_id;
        CREATE TABLE IF NOT EXISTS temperature_corrections (
            id INT DEFAULT nextval('seq_temperature_corrections_id'),
            temperature_label VARCHAR(50) NOT NULL,
            temp_from NUMERIC(5,1),
            temp_to NUMERIC(5,1),
            delta_tv NUMERIC(4,2) NOT NULL,
            description VARCHAR(255)
        );
    END;
    COMMIT;

    -- 2. Транзакция: наполнение тестовыми данными
    BEGIN
        INSERT INTO base_units (id, code, name) VALUES
        (1, 'LENGTH', 'Длина'),
        (2, 'TEMPERATURE', 'Температура'),
        (3, 'PRESSURE', 'Давление'),
        (4, 'ANGLE', 'Угол'),
        (5, 'SPEED', 'Скорость')
        ON CONFLICT DO NOTHING;

        INSERT INTO units (id, code, name, base_unit_id, convert_factor) VALUES
        (1, 'M', 'метр', 1, 1.0),
        (2, 'CELSIUS', 'градус Цельсия', 2, 1.0),
        (3, 'MMHG', 'мм рт. ст.', 3, 133.322),
        (4, 'MIL', 'больших делений угломера', 4, 1.0),
        (5, 'MPS', 'м/с', 5, 1.0)
        ON CONFLICT DO NOTHING;

        INSERT INTO positions (id, code, name) VALUES
        (1, 'CHIEF', 'Начальник метеопоста'),
        (2, 'OPERATOR', 'Оператор-метеоролог'),
        (3, 'SERGEANT', 'Сержант')
        ON CONFLICT DO NOTHING;

        INSERT INTO employees (id, code, name, birthday, position_id) VALUES
        (1, 'EMP_01', 'Воловиков Александр Сергеевич', '1978-06-24', 1),
        (2, 'EMP_02', 'Иванов Петр Иванович', '1985-03-12', 2),
        (3, 'EMP_03', 'Сидоров Алексей Викторович', '1990-11-05', 3)
        ON CONFLICT DO NOTHING;

        INSERT INTO equipment_types (id, code, name, description) VALUES
        (1, 'DMK', 'ДМК', 'Десантный метеорологический комплект'),
        (2, 'VR', 'ВР', 'Ветровое ружье')
        ON CONFLICT DO NOTHING;

        INSERT INTO parameter_types (id, code, name, unit_id, equipment_type_id) VALUES
        (1, 'HEIGHT', 'Высота метеопоста', 1, NULL),
        (2, 'TEMPERATURE', 'Температура воздуха', 2, NULL),
        (3, 'PRESSURE', 'Давление атмосферы', 3, NULL),
        (4, 'WIND_DIRECTION', 'Направление ветра', 4, NULL),
        (5, 'WIND_SPEED', 'Скорость ветра', 5, 1),
        (6, 'BULLET_DRIFT', 'Дальность сноса пуль', 1, 2)
        ON CONFLICT DO NOTHING;

        INSERT INTO temperature_corrections (id, temperature_label, temp_from, temp_to, delta_tv, description) VALUES
        (1, 'Ниже 0', NULL, 0.0, 0.0, 'Для температур ниже 0'),
        (2, '0 - 5', 0.0, 5.0, 0.5, 'Интервал от 0 до 5 градусов'),
        (3, '10 - 15', 10.0, 15.0, 1.0, 'Интервал от 10 до 15 градусов'),
        (4, '20', 20.0, 20.0, 1.5, 'При 20 градусах'),
        (5, '25', 25.0, 25.0, 2.0, 'При 25 градусах'),
        (6, '30', 30.0, 30.0, 3.5, 'При 30 градусах'),
        (7, '40', 40.0, 40.0, 4.5, 'При 40 градусах')
        ON CONFLICT DO NOTHING;

        INSERT INTO batches (id, code, employee_id, equipment_type_id, created_at) VALUES
        (1, 'BATCH_101', 1, 1, '2026-10-10 08:00:00'),
        (2, 'BATCH_102', 1, 2, '2026-10-10 08:30:00'),
        (3, 'BATCH_103', 2, 1, '2026-10-10 09:00:00'),
        (4, 'BATCH_104', 2, 2, '2026-10-10 09:30:00'),
        (5, 'BATCH_105', 3, 1, '2026-10-10 10:00:00'),
        (6, 'BATCH_106', 3, 2, '2026-10-10 10:30:00')
        ON CONFLICT DO NOTHING;

        INSERT INTO parameters (id, code, batch_id, parameter_type_id, value) VALUES
        (1, 'P_101_H', 1, 1, 100.0),
        (2, 'P_101_T', 1, 2, 15.0),
        (3, 'P_101_P', 1, 3, 750.0),
        (4, 'P_101_WD', 1, 4, 15.0),
        (5, 'P_101_WS', 1, 5, 5.0),
        (6, 'P_102_H', 2, 1, 120.0),
        (7, 'P_102_T', 2, 2, 22.0),
        (8, 'P_102_P', 2, 3, 760.0),
        (9, 'P_102_WD', 2, 4, 30.0),
        (10, 'P_102_BD', 2, 6, 45.0),
        (11, 'P_103_H', 3, 1, 80.0),
        (12, 'P_103_T', 3, 2, -10.0),
        (13, 'P_103_P', 3, 3, 740.0),
        (14, 'P_103_WD', 3, 4, 0.0),
        (15, 'P_103_WS', 3, 5, 2.0),
        (16, 'P_104_H', 4, 1, 250.0),
        (17, 'P_104_T', 4, 2, 35.0),
        (18, 'P_104_P', 4, 3, 710.0),
        (19, 'P_104_WD', 4, 4, 55.0),
        (20, 'P_104_BD', 4, 6, 110.0),
        (21, 'P_105_H', 5, 1, 300.0),
        (22, 'P_105_T', 5, 2, 0.0),
        (23, 'P_105_P', 5, 3, 755.0),
        (24, 'P_105_WD', 5, 4, 42.0),
        (25, 'P_105_WS', 5, 5, 8.0),
        (26, 'P_106_H', 6, 1, 50.0),
        (27, 'P_106_T', 6, 2, 18.5),
        (28, 'P_106_P', 6, 3, 765.0),
        (29, 'P_106_WD', 6, 4, 20.0),
        (30, 'P_106_BD', 6, 6, 15.0)
        ON CONFLICT DO NOTHING;

        PERFORM setval('seq_base_units_id', COALESCE((SELECT MAX(id) FROM base_units), 1));
        PERFORM setval('seq_units_id', COALESCE((SELECT MAX(id) FROM units), 1));
        PERFORM setval('seq_positions_id', COALESCE((SELECT MAX(id) FROM positions), 1));
        PERFORM setval('seq_employees_id', COALESCE((SELECT MAX(id) FROM employees), 1));
        PERFORM setval('seq_equipment_types_id', COALESCE((SELECT MAX(id) FROM equipment_types), 1));
        PERFORM setval('seq_parameter_types_id', COALESCE((SELECT MAX(id) FROM parameter_types), 1));
        PERFORM setval('seq_batches_id', COALESCE((SELECT MAX(id) FROM batches), 1));
        PERFORM setval('seq_parameters_id', COALESCE((SELECT MAX(id) FROM parameters), 1));
        PERFORM setval('seq_temperature_corrections_id', COALESCE((SELECT MAX(id) FROM temperature_corrections), 1));
    END;
    COMMIT;

    -- 3. Транзакция: создание связей и ограничений
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_base_units') THEN
            ALTER TABLE base_units ADD CONSTRAINT pk_base_units PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_units') THEN
            ALTER TABLE units ADD CONSTRAINT pk_units PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_positions') THEN
            ALTER TABLE positions ADD CONSTRAINT pk_positions PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_employees') THEN
            ALTER TABLE employees ADD CONSTRAINT pk_employees PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_equipment_types') THEN
            ALTER TABLE equipment_types ADD CONSTRAINT pk_equipment_types PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_parameter_types') THEN
            ALTER TABLE parameter_types ADD CONSTRAINT pk_parameter_types PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_batches') THEN
            ALTER TABLE batches ADD CONSTRAINT pk_batches PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_parameters') THEN
            ALTER TABLE parameters ADD CONSTRAINT pk_parameters PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_temperature_corrections') THEN
            ALTER TABLE temperature_corrections ADD CONSTRAINT pk_temperature_corrections PRIMARY KEY (id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_base_units_code') THEN
            ALTER TABLE base_units ADD CONSTRAINT uq_base_units_code UNIQUE (code);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_units_code') THEN
            ALTER TABLE units ADD CONSTRAINT uq_units_code UNIQUE (code);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_positions_code') THEN
            ALTER TABLE positions ADD CONSTRAINT uq_positions_code UNIQUE (code);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_employees_code') THEN
            ALTER TABLE employees ADD CONSTRAINT uq_employees_code UNIQUE (code);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_equipment_types_code') THEN
            ALTER TABLE equipment_types ADD CONSTRAINT uq_equipment_types_code UNIQUE (code);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_parameter_types_code') THEN
            ALTER TABLE parameter_types ADD CONSTRAINT uq_parameter_types_code UNIQUE (code);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_batches_code') THEN
            ALTER TABLE batches ADD CONSTRAINT uq_batches_code UNIQUE (code);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_parameters_code') THEN
            ALTER TABLE parameters ADD CONSTRAINT uq_parameters_code UNIQUE (code);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_units_base_unit') THEN
            ALTER TABLE units 
                ADD CONSTRAINT fk_units_base_unit 
                FOREIGN KEY (base_unit_id) REFERENCES base_units(id) ON DELETE RESTRICT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_employees_position') THEN
            ALTER TABLE employees 
                ADD CONSTRAINT fk_employees_position 
                FOREIGN KEY (position_id) REFERENCES positions(id) ON DELETE SET NULL;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_parameter_types_unit') THEN
            ALTER TABLE parameter_types 
                ADD CONSTRAINT fk_parameter_types_unit 
                FOREIGN KEY (unit_id) REFERENCES units(id) ON DELETE RESTRICT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_parameter_types_equipment') THEN
            ALTER TABLE parameter_types 
                ADD CONSTRAINT fk_parameter_types_equipment 
                FOREIGN KEY (equipment_type_id) REFERENCES equipment_types(id) ON DELETE SET NULL;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_batches_employee') THEN
            ALTER TABLE batches 
                ADD CONSTRAINT fk_batches_employee 
                FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_batches_equipment') THEN
            ALTER TABLE batches 
                ADD CONSTRAINT fk_batches_equipment 
                FOREIGN KEY (equipment_type_id) REFERENCES equipment_types(id) ON DELETE RESTRICT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_parameters_batch') THEN
            ALTER TABLE parameters 
                ADD CONSTRAINT fk_parameters_batch 
                FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE CASCADE;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_parameters_parameter_type') THEN
            ALTER TABLE parameters 
                ADD CONSTRAINT fk_parameters_parameter_type 
                FOREIGN KEY (parameter_type_id) REFERENCES parameter_types(id) ON DELETE RESTRICT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_parameters_value_ranges') THEN
            ALTER TABLE parameters 
                ADD CONSTRAINT chk_parameters_value_ranges 
                CHECK (
                    (parameter_type_id = 1 AND value BETWEEN -100 AND 5000) OR
                    (parameter_type_id = 2 AND value BETWEEN -58.0 AND 58.0) OR
                    (parameter_type_id = 3 AND value BETWEEN 500 AND 900) OR
                    (parameter_type_id = 4 AND value BETWEEN 0 AND 59) OR
                    (parameter_type_id = 5 AND value BETWEEN 0 AND 15) OR
                    (parameter_type_id = 6 AND value BETWEEN 0 AND 150)
                );
        END IF;
    END;
    COMMIT;
END;
$$;
