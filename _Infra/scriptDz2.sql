CREATE TABLE IF NOT EXISTS equipment_types (
    id INT,
    code VARCHAR(20),
    name VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS positions (
    id INT,
    code VARCHAR(20),
    name VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS users (
    id INT,
    code VARCHAR(20),
    name VARCHAR(100),
    position_id INT
);

CREATE TABLE IF NOT EXISTS batches (
    id INT,
    code VARCHAR(20),
    user_id INT,
    equipment_type_id INT,
    created_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS parameters (
    id INT,
    code VARCHAR(20),
    batch_id INT,
    height INT,
    temperature DECIMAL(5,1),
    pressure INT,
    wind_direction INT,
    wind_speed INT,
    bullet_drift INT
);

INSERT INTO equipment_types (id, code, name)
SELECT 1, 'EQ_DMK', 'ДМК'
WHERE NOT EXISTS (SELECT 1 FROM equipment_types WHERE id = 1);

INSERT INTO equipment_types (id, code, name)
SELECT 2, 'EQ_VR', 'ВР'
WHERE NOT EXISTS (SELECT 1 FROM equipment_types WHERE id = 2);

INSERT INTO positions (id, code, name)
SELECT 1, 'POS_01', 'Начальник метеопоста'
WHERE NOT EXISTS (SELECT 1 FROM positions WHERE id = 1);

INSERT INTO positions (id, code, name)
SELECT 2, 'POS_02', 'Оператор'
WHERE NOT EXISTS (SELECT 1 FROM positions WHERE id = 2);

INSERT INTO users (id, code, name, position_id)
SELECT 1, 'USR_01', 'Иванов И.И.', 1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE id = 1);

INSERT INTO users (id, code, name, position_id)
SELECT 2, 'USR_02', 'Петров П.П.', 2
WHERE NOT EXISTS (SELECT 1 FROM users WHERE id = 2);

INSERT INTO batches (id, code, user_id, equipment_type_id, created_at)
SELECT 1, 'BATCH_01', 1, 1, TIMESTAMP '2026-09-21 10:00:00'
WHERE NOT EXISTS (SELECT 1 FROM batches WHERE id = 1);

INSERT INTO batches (id, code, user_id, equipment_type_id, created_at)
SELECT 2, 'BATCH_02', 2, 2, TIMESTAMP '2026-09-21 11:00:00'
WHERE NOT EXISTS (SELECT 1 FROM batches WHERE id = 2);

INSERT INTO parameters (id, code, batch_id, height, temperature, pressure, wind_direction, wind_speed, bullet_drift)
SELECT 1, 'PARAM_01', 1, 100, 15.0, 750, 0, 0, NULL
WHERE NOT EXISTS (SELECT 1 FROM parameters WHERE id = 1);

INSERT INTO parameters (id, code, batch_id, height, temperature, pressure, wind_direction, wind_speed, bullet_drift)
SELECT 2, 'PARAM_02', 2, 100, 25.0, 765, 15, 6, 10
WHERE NOT EXISTS (SELECT 1 FROM parameters WHERE id = 2);

SELECT
    b.code AS batch_code,
    b.created_at,
    et.name AS equipment_type,
    u.name AS user_name,
    p.name AS position_name,
    par.height,
    par.temperature,
    par.pressure,
    par.wind_direction,
    par.wind_speed,
    par.bullet_drift
FROM batches b, equipment_types et, users u, positions p, parameters par
WHERE b.equipment_type_id = et.id
  AND b.user_id = u.id
  AND u.position_id = p.id
  AND b.id = par.batch_id;
