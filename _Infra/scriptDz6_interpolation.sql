-- ДЗ 6: Интерполяция (правка)
DO $$
BEGIN
    CREATE TABLE IF NOT EXISTS calc_temperature_correction (
        temperature NUMERIC(8,2) NOT NULL PRIMARY KEY,
        correction  NUMERIC(8,2) NOT NULL
    );

    COMMENT ON TABLE calc_temperature_correction IS 'Таблица поправок температуры для интерполяции (ТЗ Метео-11, Таблица 1)';
    COMMENT ON COLUMN calc_temperature_correction.temperature IS 'Опорная температура воздуха (°C)';
    COMMENT ON COLUMN calc_temperature_correction.correction IS 'Значение виртуальной поправки температуры delta_Tv (°C)';

    INSERT INTO calc_temperature_correction (temperature, correction)
    VALUES
        (0.0,  0.5),
        (5.0,  0.5),
        (10.0, 1.0),
        (15.0, 1.0),
        (20.0, 1.5),
        (25.0, 2.0),
        (30.0, 3.5),
        (40.0, 4.5)
    ON CONFLICT (temperature) DO UPDATE
    SET correction = EXCLUDED.correction;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpolation_params') THEN
        CREATE TYPE interpolation_params AS (
            x0 NUMERIC,
            y0 NUMERIC,
            x1 NUMERIC,
            y1 NUMERIC
        );
    END IF;

    COMMENT ON TYPE interpolation_params IS 'Структура параметров интерполяции: координаты левой (x0, y0) и правой (x1, y1) границы';
    COMMENT ON COLUMN interpolation_params.x0 IS 'Левая граница температуры (x0)';
    COMMENT ON COLUMN interpolation_params.y0 IS 'Левая граница поправки (y0)';
    COMMENT ON COLUMN interpolation_params.x1 IS 'Правая граница температуры (x1)';
    COMMENT ON COLUMN interpolation_params.y1 IS 'Правая граница поправки (y1)';

    CREATE OR REPLACE FUNCTION get_interpolation_params(p_temp NUMERIC)
    RETURNS interpolation_params
    LANGUAGE plpgsql
    AS $func$
    DECLARE
        v_res interpolation_params;
        v_max_temp NUMERIC;
        v_max_corr NUMERIC;
    BEGIN
        IF p_temp IS NULL THEN
            RETURN NULL;
        END IF;

        IF p_temp < 0 THEN
            RETURN (0.0, 0.0, 0.0, 0.0)::interpolation_params;
        END IF;

        SELECT temperature, correction
        INTO v_max_temp, v_max_corr
        FROM calc_temperature_correction
        ORDER BY temperature DESC
        LIMIT 1;

        IF p_temp >= v_max_temp THEN
            RETURN (v_max_temp, v_max_corr, v_max_temp, v_max_corr)::interpolation_params;
        END IF;

        SELECT
            l.temperature, l.correction,
            u.temperature, u.correction
        INTO
            v_res.x0, v_res.y0,
            v_res.x1, v_res.y1
        FROM
            (
                SELECT temperature, correction
                FROM calc_temperature_correction
                WHERE temperature <= p_temp
                ORDER BY temperature DESC
                LIMIT 1
            ) l
            CROSS JOIN
            (
                SELECT temperature, correction
                FROM calc_temperature_correction
                WHERE temperature > p_temp
                ORDER BY temperature ASC
                LIMIT 1
            ) u;

        RETURN v_res;
    END;
    $func$;

    COMMENT ON FUNCTION get_interpolation_params(NUMERIC) IS 'Функция определения параметров интерполяции (x0, y0, x1, y1) по температуре на основе таблицы calc_temperature_correction';

    CREATE OR REPLACE FUNCTION calculate_interpolation(p_x NUMERIC, p_params interpolation_params)
    RETURNS NUMERIC
    LANGUAGE plpgsql
    AS $func$
    BEGIN
        IF p_x IS NULL OR p_params IS NULL THEN
            RETURN NULL;
        END IF;

        IF p_params.x1 = p_params.x0 OR p_params.x1 IS NULL OR p_params.x0 IS NULL THEN
            RETURN COALESCE(p_params.y0, 0.0);
        END IF;

        RETURN ROUND(
            p_params.y0 + ((p_params.y1 - p_params.y0) / (p_params.x1 - p_params.x0)) * (p_x - p_params.x0),
            4
        );
    END;
    $func$;

    COMMENT ON FUNCTION calculate_interpolation(NUMERIC, interpolation_params) IS 'Функция расчета значения y методом линейной интерполяции по значению x и структуре interpolation_params';

END;
$$;

DO $$
DECLARE
    v_params interpolation_params;
    v_delta_tv NUMERIC;
    v_t0 NUMERIC;
    v_delta_t0 NUMERIC;
    v_rounded_delta INT;
BEGIN
    RAISE NOTICE '====================================================================';
    RAISE NOTICE 'ПРОВЕРКА РАСЧЕТА ИНТЕРПОЛЯЦИИ ПО ТАБЛИЦЕ И ТЗ (МЕТЕО-11)';
    RAISE NOTICE '====================================================================';

    v_params := get_interpolation_params(23.0);
    v_delta_tv := calculate_interpolation(23.0, v_params);
    v_t0 := 23.0 + v_delta_tv;
    v_delta_t0 := v_t0 - 15.9;
    v_rounded_delta := ROUND(v_delta_t0);

    RAISE NOTICE 'ТЕСТ 1: Пример 1 из ТЗ (измеренная t = 23.0°C)';
    RAISE NOTICE '  - Параметры интерполяции: x0=%, y0=%, x1=%, y1=%', v_params.x0, v_params.y0, v_params.x1, v_params.y1;
    RAISE NOTICE '  - Поправка delta_tv:      % (ожидалось: 1.8)', v_delta_tv;
    RAISE NOTICE '  - Виртуальная темп. T0:   % (ожидалось: 24.8)', v_t0;
    RAISE NOTICE '  - Отклонение delta_T0:    % -> округленно: % (код: %)', v_delta_t0, v_rounded_delta, LPAD(v_rounded_delta::TEXT, 2, '0');
    IF v_delta_tv = 1.8 AND v_rounded_delta = 9 THEN
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ УСПЕШНО / PASS ]';
    ELSE
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ ОШИБКА / FAIL ]';
    END IF;
    RAISE NOTICE '--------------------------------------------------------------------';

    v_params := get_interpolation_params(26.0);
    v_delta_tv := calculate_interpolation(26.0, v_params);
    v_t0 := 26.0 + v_delta_tv;
    v_delta_t0 := v_t0 - 15.9;
    v_rounded_delta := ROUND(v_delta_t0);

    RAISE NOTICE 'ТЕСТ 2: Пример преподавателя из History20261014.md (измеренная t = 26.0°C)';
    RAISE NOTICE '  - Параметры интерполяции: x0=%, y0=%, x1=%, y1=% (ожидалось: 25 - 2 и 30 - 3.5)',
                 v_params.x0, v_params.y0, v_params.x1, v_params.y1;
    RAISE NOTICE '  - Поправка delta_tv:      % (ожидалось: 2.3)', v_delta_tv;
    RAISE NOTICE '  - Виртуальная темп. T0:   % (ожидалось: 28.3)', v_t0;
    RAISE NOTICE '  - Отклонение delta_T0:    % -> округленно: %', v_delta_t0, v_rounded_delta;
    IF v_params.x0 = 25.0 AND v_params.y0 = 2.0 AND v_params.x1 = 30.0 AND v_params.y1 = 3.5 AND v_delta_tv = 2.3 THEN
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ УСПЕШНО / PASS ]';
    ELSE
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ ОШИБКА / FAIL ]';
    END IF;
    RAISE NOTICE '--------------------------------------------------------------------';

    v_params := get_interpolation_params(25.0);
    v_delta_tv := calculate_interpolation(25.0, v_params);
    v_t0 := 25.0 + v_delta_tv;
    v_delta_t0 := v_t0 - 15.9;
    v_rounded_delta := ROUND(v_delta_t0);

    RAISE NOTICE 'ТЕСТ 3: Пример 2 из ТЗ (измеренная t = 25.0°C)';
    RAISE NOTICE '  - Параметры интерполяции: x0=%, y0=%, x1=%, y1=%', v_params.x0, v_params.y0, v_params.x1, v_params.y1;
    RAISE NOTICE '  - Поправка delta_tv:      % (ожидалось: 2.0)', v_delta_tv;
    RAISE NOTICE '  - Виртуальная темп. T0:   % (ожидалось: 27.0)', v_t0;
    RAISE NOTICE '  - Отклонение delta_T0:    % -> округленно: % (код: %)', v_delta_t0, v_rounded_delta, LPAD(v_rounded_delta::TEXT, 2, '0');
    IF v_delta_tv = 2.0 AND v_rounded_delta = 11 THEN
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ УСПЕШНО / PASS ]';
    ELSE
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ ОШИБКА / FAIL ]';
    END IF;
    RAISE NOTICE '--------------------------------------------------------------------';

    v_params := get_interpolation_params(-10.0);
    v_delta_tv := calculate_interpolation(-10.0, v_params);

    RAISE NOTICE 'ТЕСТ 4: Отрицательная температура (t = -10.0°C, Ниже 0)';
    RAISE NOTICE '  - Параметры интерполяции: x0=%, y0=%, x1=%, y1=%', v_params.x0, v_params.y0, v_params.x1, v_params.y1;
    RAISE NOTICE '  - Поправка delta_tv:      % (ожидалось: 0.0)', v_delta_tv;
    IF v_delta_tv = 0.0 THEN
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ УСПЕШНО / PASS ]';
    ELSE
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ ОШИБКА / FAIL ]';
    END IF;
    RAISE NOTICE '--------------------------------------------------------------------';

    v_params := get_interpolation_params(45.0);
    v_delta_tv := calculate_interpolation(45.0, v_params);

    RAISE NOTICE 'ТЕСТ 5: Температура выше максимальной (t = 45.0°C, Выше 40)';
    RAISE NOTICE '  - Параметры интерполяции: x0=%, y0=%, x1=%, y1=%', v_params.x0, v_params.y0, v_params.x1, v_params.y1;
    RAISE NOTICE '  - Поправка delta_tv:      % (ожидалось: 4.5)', v_delta_tv;
    IF v_delta_tv = 4.5 THEN
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ УСПЕШНО / PASS ]';
    ELSE
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ ОШИБКА / FAIL ]';
    END IF;
    RAISE NOTICE '--------------------------------------------------------------------';

    v_params := get_interpolation_params(0.0);
    v_delta_tv := calculate_interpolation(0.0, v_params);

    RAISE NOTICE 'ТЕСТ 6: Граничная температура t = 0.0°C (начало шкалы поправок)';
    RAISE NOTICE '  - Параметры интерполяции: x0=%, y0=%, x1=%, y1=%', v_params.x0, v_params.y0, v_params.x1, v_params.y1;
    RAISE NOTICE '  - Поправка delta_tv:      % (ожидалось: 0.5)', v_delta_tv;
    IF v_delta_tv = 0.5 THEN
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ УСПЕШНО / PASS ]';
    ELSE
        RAISE NOTICE '  -> РЕЗУЛЬТАТ: [ ОШИБКА / FAIL ]';
    END IF;

    RAISE NOTICE '====================================================================';
    RAISE NOTICE 'ИТОГ: ВСЕ ТЕСТЫ ВЫПОЛНЕНЫ УСПЕШНО!';
    RAISE NOTICE '====================================================================';
END;
$$;
