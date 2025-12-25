-- datelist_int generation query.
-- Convert the device_activity_datelist column into a datelist_int column

WITH users AS (SELECT *
               FROM user_devices_cumulated
               WHERE date = DATE('2023-01-31')),

     series AS (SELECT *
                FROM GENERATE_SERIES(
                             DATE('2023-01-01'),
                             DATE('2023-01-31'),
                             INTERVAL '1 day')
                         AS series_date),

     place_holder_ints AS (SELECT CASE
                                      WHEN device_activity_datelist @> ARRAY [DATE(series_date)]
                                          THEN POW(2, 31 - (date - DATE(series_date)))
                                      ELSE 0
                                      END AS placeholder_int_value,
                                  *
                           FROM users
                                    CROSS JOIN series)


SELECT user_id,
       browser_type,
       CAST(SUM(placeholder_int_value) AS BIGINT)                             AS datelist_int,
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))            AS datelist_int_binary,
       BIT_COUNT(CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) AS cnt_active_days,
       date
FROM place_holder_ints
GROUP BY user_id,
         browser_type,
         date;