CREATE TABLE base_units (
    id INT,
    code VARCHAR(20),
    name VARCHAR(100)
);

COMMENT ON TABLE base_units IS 'Справочник базовых единиц измерения';
COMMENT ON COLUMN base_units.id IS 'Идентификатор';
COMMENT ON COLUMN base_units.code IS 'Код';
COMMENT ON COLUMN base_units.name IS 'Наименование';

CREATE TABLE units (
    id INT,
    code VARCHAR(20),
    name VARCHAR(100),
    base_unit_id INT
);

COMMENT ON TABLE units IS 'Справочник единиц измерения';
COMMENT ON COLUMN units.id IS 'Идентификатор';
COMMENT ON COLUMN units.code IS 'Код';
COMMENT ON COLUMN units.name IS 'Наименование';
COMMENT ON COLUMN units.base_unit_id IS 'Ссылка на базовую единицу измерения';

CREATE TABLE parameter_types (
    id INT,
    code VARCHAR(20),
    name VARCHAR(100),
    unit_id INT
);

COMMENT ON TABLE parameter_types IS 'Справочник типов параметров';
COMMENT ON COLUMN parameter_types.id IS 'Идентификатор';
COMMENT ON COLUMN parameter_types.code IS 'Код';
COMMENT ON COLUMN parameter_types.name IS 'Наименование';
COMMENT ON COLUMN parameter_types.unit_id IS 'Ссылка на единицу измерения';

INSERT INTO base_units (id, code, name)
SELECT 1, 'LENGTH', 'Длина'
WHERE NOT EXISTS (SELECT 1 FROM base_units WHERE id = 1);

INSERT INTO base_units (id, code, name)
SELECT 2, 'TEMPERATURE', 'Температура'
WHERE NOT EXISTS (SELECT 1 FROM base_units WHERE id = 2);

INSERT INTO base_units (id, code, name)
SELECT 3, 'PRESSURE', 'Давление'
WHERE NOT EXISTS (SELECT 1 FROM base_units WHERE id = 3);

INSERT INTO base_units (id, code, name)
SELECT 4, 'ANGLE', 'Угол'
WHERE NOT EXISTS (SELECT 1 FROM base_units WHERE id = 4);

INSERT INTO base_units (id, code, name)
SELECT 5, 'SPEED', 'Скорость'
WHERE NOT EXISTS (SELECT 1 FROM base_units WHERE id = 5);

INSERT INTO units (id, code, name, base_unit_id)
SELECT 1, 'M', 'м', 1
WHERE NOT EXISTS (SELECT 1 FROM units WHERE id = 1);

INSERT INTO units (id, code, name, base_unit_id)
SELECT 2, 'CELSIUS', '°C', 2
WHERE NOT EXISTS (SELECT 1 FROM units WHERE id = 2);

INSERT INTO units (id, code, name, base_unit_id)
SELECT 3, 'MMHG', 'мм рт. ст.', 3
WHERE NOT EXISTS (SELECT 1 FROM units WHERE id = 3);

INSERT INTO units (id, code, name, base_unit_id)
SELECT 4, 'MIL', 'больших делений угломера', 4
WHERE NOT EXISTS (SELECT 1 FROM units WHERE id = 4);

INSERT INTO units (id, code, name, base_unit_id)
SELECT 5, 'MPS', 'м/с', 5
WHERE NOT EXISTS (SELECT 1 FROM units WHERE id = 5);

INSERT INTO parameter_types (id, code, name, unit_id)
SELECT 1, 'HEIGHT', 'Высота метеопоста', 1
WHERE NOT EXISTS (SELECT 1 FROM parameter_types WHERE id = 1);

INSERT INTO parameter_types (id, code, name, unit_id)
SELECT 2, 'TEMPERATURE', 'Температура воздуха', 2
WHERE NOT EXISTS (SELECT 1 FROM parameter_types WHERE id = 2);

INSERT INTO parameter_types (id, code, name, unit_id)
SELECT 3, 'PRESSURE', 'Давление атмосферы', 3
WHERE NOT EXISTS (SELECT 1 FROM parameter_types WHERE id = 3);

INSERT INTO parameter_types (id, code, name, unit_id)
SELECT 4, 'WIND_DIRECTION', 'Направление ветра', 4
WHERE NOT EXISTS (SELECT 1 FROM parameter_types WHERE id = 4);

INSERT INTO parameter_types (id, code, name, unit_id)
SELECT 5, 'WIND_SPEED', 'Скорость ветра', 5
WHERE NOT EXISTS (SELECT 1 FROM parameter_types WHERE id = 5);

INSERT INTO parameter_types (id, code, name, unit_id)
SELECT 6, 'BULLET_DRIFT', 'Дальность сноса пуль', 1
WHERE NOT EXISTS (SELECT 1 FROM parameter_types WHERE id = 6);

CREATE TABLE parameters_v2 (
    id INT,
    code VARCHAR(50),
    batch_id INT,
    parameter_type_id INT,
    value DECIMAL(10,2)
);

INSERT INTO parameters_v2 (id, code, batch_id, parameter_type_id, value)
SELECT id * 10 + 1, code || '_HEIGHT', batch_id, 1, height
FROM parameters
WHERE height IS NOT NULL
UNION ALL
SELECT id * 10 + 2, code || '_TEMPERATURE', batch_id, 2, temperature
FROM parameters
WHERE temperature IS NOT NULL
UNION ALL
SELECT id * 10 + 3, code || '_PRESSURE', batch_id, 3, pressure
FROM parameters
WHERE pressure IS NOT NULL
UNION ALL
SELECT id * 10 + 4, code || '_WIND_DIRECTION', batch_id, 4, wind_direction
FROM parameters
WHERE wind_direction IS NOT NULL
UNION ALL
SELECT id * 10 + 5, code || '_WIND_SPEED', batch_id, 5, wind_speed
FROM parameters
WHERE wind_speed IS NOT NULL
UNION ALL
SELECT id * 10 + 6, code || '_BULLET_DRIFT', batch_id, 6, bullet_drift
FROM parameters
WHERE bullet_drift IS NOT NULL;

DELETE FROM parameters;

DROP TABLE parameters;

CREATE TABLE parameters (
    id INT,
    code VARCHAR(50),
    batch_id INT,
    parameter_type_id INT,
    value DECIMAL(10,2)
);

COMMENT ON TABLE parameters IS 'Нормализованные значения параметров измерений';
COMMENT ON COLUMN parameters.id IS 'Идентификатор';
COMMENT ON COLUMN parameters.code IS 'Код записи';
COMMENT ON COLUMN parameters.batch_id IS 'Ссылка на пачку измерений';
COMMENT ON COLUMN parameters.parameter_type_id IS 'Ссылка на тип параметра';
COMMENT ON COLUMN parameters.value IS 'Значение параметра';

INSERT INTO parameters (id, code, batch_id, parameter_type_id, value)
SELECT id, code, batch_id, parameter_type_id, value
FROM parameters_v2;

DROP TABLE parameters_v2;

SELECT
    b.created_at AS "Дата измерения",
    b.code AS "Номер пачки",
    u.name AS "ФИО сотрудника",
    pt.name || ' (' || un.name || ')' AS "Наименование параметра и ед. измерения",
    p.value AS "Значение"
FROM batches b, users u, parameters p, parameter_types pt, units un
WHERE b.user_id = u.id
  AND b.id = p.batch_id
  AND p.parameter_type_id = pt.id
  AND pt.unit_id = un.id
ORDER BY b.created_at, b.code, pt.id;
