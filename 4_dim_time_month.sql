-- 1. Создание таблицы временных метрик
CREATE TABLE dim_time_month (
    month_id            INT PRIMARY KEY,
    month_start_date    DATE NOT NULL,
    month_end_date      DATE NOT NULL, 
    month_name          TEXT NOT NULL, 
    year_number         INT NOT NULL, 
    quarter_number      INT NOT NULL, 
    quarter_name        TEXT NOT NULL 
);

-- 2. PL/pgSQL блок наполнения метрик
DO $$
DECLARE
    cur_date DATE := '2018-01-01';
    end_date DATE := '2030-12-01';
BEGIN
    WHILE cur_date <= end_date LOOP
        INSERT INTO dim_time_month (
            month_id,
            month_start_date,
            month_end_date,
            month_name,
            year_number,
            quarter_number,
            quarter_name
        )
        VALUES (
            to_char(cur_date, 'YYYYMM')::INT,
            cur_date,
            (cur_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE,
            CASE EXTRACT(MONTH FROM cur_date)
                WHEN 1 THEN 'Январь'
                WHEN 2 THEN 'Февраль'
                WHEN 3 THEN 'Март'
                WHEN 4 THEN 'Апрель'
                WHEN 5 THEN 'Май'
                WHEN 6 THEN 'Июнь'
                WHEN 7 THEN 'Июль'
                WHEN 8 THEN 'Август'
                WHEN 9 THEN 'Сентябрь'
                WHEN 10 THEN 'Октябрь'
                WHEN 11 THEN 'Ноябрь'
                WHEN 12 THEN 'Декабрь'
            END,
            EXTRACT(YEAR FROM cur_date)::INT,
            EXTRACT(QUARTER FROM cur_date)::INT,
            EXTRACT(QUARTER FROM cur_date)::TEXT || ' квартал'
        )
        ON CONFLICT (month_id) DO NOTHING;

        cur_date := cur_date + INTERVAL '1 month';
    END LOOP;
END;
$$;

-- Проверка наполнения:
SELECT * FROM dim_time_month ORDER BY month_id LIMIT 12;