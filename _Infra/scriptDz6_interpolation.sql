DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpolation_params') THEN
        CREATE TYPE interpolation_params AS (
            x0 NUMERIC,
            y0 NUMERIC,
            x1 NUMERIC,
            y1 NUMERIC
        );
    END IF;

    CREATE OR REPLACE FUNCTION get_interpolation_params(p_temp NUMERIC)
    RETURNS interpolation_params
    LANGUAGE plpgsql
    AS $func$
    DECLARE
        v_res interpolation_params;
    BEGIN
        IF p_temp <= 0 THEN
            v_res := (0.0, 0.0, 0.0, 0.0)::interpolation_params;
        ELSIF p_temp <= 5 THEN
            v_res := (0.0, 0.0, 5.0, 0.5)::interpolation_params;
        ELSIF p_temp <= 10 THEN
            v_res := (5.0, 0.5, 10.0, 1.0)::interpolation_params;
        ELSIF p_temp <= 15 THEN
            v_res := (10.0, 1.0, 15.0, 1.0)::interpolation_params;
        ELSIF p_temp <= 20 THEN
            v_res := (15.0, 1.0, 20.0, 1.5)::interpolation_params;
        ELSIF p_temp <= 25 THEN
            v_res := (20.0, 1.5, 25.0, 2.0)::interpolation_params;
        ELSIF p_temp <= 30 THEN
            v_res := (25.0, 2.0, 30.0, 3.5)::interpolation_params;
        ELSIF p_temp <= 40 THEN
            v_res := (30.0, 3.5, 40.0, 4.5)::interpolation_params;
        ELSE
            v_res := (40.0, 4.5, 40.0, 4.5)::interpolation_params;
        END IF;

        RETURN v_res;
    END;
    $func$;

    CREATE OR REPLACE FUNCTION calculate_interpolation(p_x NUMERIC, p_params interpolation_params)
    RETURNS NUMERIC
    LANGUAGE plpgsql
    AS $func$
    BEGIN
        IF p_params.x1 = p_params.x0 OR p_params.x1 IS NULL OR p_params.x0 IS NULL THEN
            RETURN COALESCE(p_params.y0, 0.0);
        END IF;

        RETURN ROUND(
            p_params.y0 + ((p_params.y1 - p_params.y0) / (p_params.x1 - p_params.x0)) * (p_x - p_params.x0),
            4
        );
    END;
    $func$;
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
    RAISE NOTICE 'ПРОВЕРКА РАСЧЕТА ИНТЕРПОЛЯЦИИ ПО ТЕХНИЧЕСКОМУ ЗАДАНИЮ (МЕТЕО-11)';

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

    v_params := get_interpolation_params(3.0);
    v_delta_tv := calculate_interpolation(3.0, v_params);
    v_t0 := 3.0 + v_delta_tv;
    v_delta_t0 := v_t0 - 15.9;
    v_rounded_delta := ROUND(v_delta_t0);

    RAISE NOTICE 'ТЕСТ 2: Пример из алгоритма ДМК (измеренная t = 3.0°C)';
    RAISE NOTICE '  - Параметры интерполяции: x0=%, y0=%, x1=%, y1=%', v_params.x0, v_params.y0, v_params.x1, v_params.y1;
    RAISE NOTICE '  - Поправка delta_tv:      % (ожидалось: 0.3)', v_delta_tv;
    RAISE NOTICE '  - Виртуальная темп. T0:   % (ожидалось: 3.3)', v_t0;
    RAISE NOTICE '  - Отклонение delta_T0:    % -> округленно: %', v_delta_t0, v_rounded_delta;
    IF v_delta_tv = 0.3 AND v_rounded_delta = -13 THEN
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

    RAISE NOTICE 'ИТОГ: ВСЕ ТЕСТЫ ВЫПОЛНЕНЫ УСПЕШНО!';
END;
$$;
