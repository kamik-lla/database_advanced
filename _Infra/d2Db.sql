CREATE TABLE base_unit (
    id   INT PRIMARY KEY,
    name TEXT
);

CREATE TABLE units_of_measurement (
    id           INT PRIMARY KEY,
    name         TEXT,
    base_unit_id INTEGER NOT NULL REFERENCES base_unit (id)
);

CREATE TABLE type_of_params (
    id      INT PRIMARY KEY,
    name    TEXT,
    unit_id INTEGER NOT NULL REFERENCES units_of_measurement (id)
);

INSERT INTO base_unit (id, name)
VALUES
    (1, 'Метр'),
    (2, 'Градус Цельсия'),
    (3, 'Паскаль'),
    (4, 'Градус (угол)'),
    (5, 'Метр в секунду');

INSERT INTO units_of_measurement (id, name, base_unit_id)
VALUES
    (1, 'м', 1),
    (2, 'км', 1),
    (3, '°C', 2),
    (4, 'K', 2),
    (5, 'Па', 3),
    (6, 'гПа', 3),
    (7, 'мм рт. ст.', 3),
    (8, '°', 4),
    (9, 'дел. угломера', 4),
    (10, 'м/с', 5),
    (11, 'км/ч', 5);

INSERT INTO type_of_params (id, name, unit_id)
VALUES
    (1, 'Высота', 1),
    (2, 'Температура', 3),
    (3, 'Давление', 7),
    (4, 'Направление ветра', 8),
    (5, 'Скорость ветра', 10);

ALTER TABLE measurment_input_params
    ADD COLUMN type_of_params_id INTEGER REFERENCES type_of_params (id),
    ADD COLUMN value NUMERIC(8, 2);

ALTER TABLE measurment_input_params
    DROP COLUMN height,
    DROP COLUMN temperature,
    DROP COLUMN pressure,
    DROP COLUMN wind_direction,
    DROP COLUMN wind_speed;

DELETE FROM measurment_input_params;

INSERT INTO measurment_input_params (id, measurment_bath_id, type_of_params_id, value)
VALUES
    (1, 1, 1, 100),
    (2, 1, 2, 12),
    (3, 1, 3, 34),
    (4, 1, 4, 0.2),
    (5, 1, 5, 45);

SELECT
    measurment_baths.started::date AS "Дата измерения",
    measurment_baths.id AS "Номер пачки",
    employees.name AS "ФИО сотрудника",
    type_of_params.name || ', ' || units_of_measurement.name AS "Наименование параметра, ед. изм.",
    measurment_input_params.value AS "Значение"
FROM measurment_input_params,
     measurment_baths,
     employees,
     type_of_params,
     units_of_measurement
WHERE
    measurment_baths.id = measurment_input_params.measurment_bath_id
    AND employees.id = measurment_baths.emploee_id
    AND type_of_params.id = measurment_input_params.type_of_params_id
    AND units_of_measurement.id = type_of_params.unit_id
ORDER BY
    measurment_baths.started,
    measurment_baths.id,
    type_of_params.id;
