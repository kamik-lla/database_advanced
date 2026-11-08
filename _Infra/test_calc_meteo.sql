-- Скрипт 2: test_calc_meteo.sql
-- 1. Анонимный блок PL/pgSQL запуска расчетов
DO $$
DECLARE
    -- Параметры для ДМК (Десантный метеокомплект)
    params_dmk input_params_type;
    
    -- Параметры для ВР (Ветровое ружье)
    params_vr  input_params_type;
BEGIN
    RAISE NOTICE ' Запуск проверочных расчетов бюллетеня «Метео-11 приближенный»';

    -- 1.1 Тест 1: Расчет по прибору ДМК
    params_dmk.height                  := 100;  -- Высота метеопоста, м
    params_dmk.pressure                := 765;  -- Наземное давление, мм рт. ст.
    params_dmk.temperature             := 25;   -- Температура воздуха, °C
    params_dmk.wind_direction          := 15;   -- Направление ветра, дел. угл.
    params_dmk.wind_speed              := 6;    -- Скорость приземного ветра, м/с
    params_dmk.bullet_demolition_range := 0;    -- Не используется для ДМК

    RAISE NOTICE '-> Запуск расчета для ДМК (equipment_type = 1)...';
    CALL public.sp_calc_meteo_approximate(params_dmk, 1);

    -- 1.2 Тест 2: Расчет по прибору ВР
    params_vr.height                  := 60;   -- Высота метеопоста, м
    params_vr.pressure                := 757;  -- Наземное давление, мм рт. ст.
    params_vr.temperature             := 23;   -- Температура воздуха, °C
    params_vr.wind_direction          := 10;   -- Направление ветра, дел. угл.
    params_vr.wind_speed              := 0;    -- Не используется для ВР
    params_vr.bullet_demolition_range := 80;   -- Дальность сноса пуль Dг, м

    RAISE NOTICE '-> Запуск расчета для ВР (equipment_type = 2)...';
    CALL public.sp_calc_meteo_approximate(params_vr, 2);

    RAISE NOTICE ' Расчеты успешно завершены! Смотрите сводную таблицу в Data Output.';
END;
$$;

-- 2. Сводная таблица результатов для скриншота в отчет
SELECT 
    equipment_name      AS "Прибор",
    bulletin_header     AS "Заголовок бюллетеня",
    height_m            AS "Высота H (м)",
    height_code         AS "Код H",
    temp_correction     AS "TT (поправка)",
    wind_direction      AS "HH (направление)",
    wind_speed          AS "CC (скорость)",
    bulletin_line       AS "Строка бюллетеня"
FROM public.meteo_bulletin_results
ORDER BY equipment_id ASC, height_m ASC;
