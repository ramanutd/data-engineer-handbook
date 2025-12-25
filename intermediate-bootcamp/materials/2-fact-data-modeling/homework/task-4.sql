-- TASK 4: Convert device_activity_datelist array into compressed integer representation
--
-- This query converts an array of activity dates into a single integer using bit encoding:
-- 1. Generate a series of all dates in the month (Jan 1-31, 2023)
-- 2. For each date in the series, check if it exists in the user's device_activity_datelist
-- 3. If the date exists, calculate its bit position: POW(2, 31 - days_from_end)
--    - Day 31 (Jan 31) gets bit position 0 (rightmost): 2^0 = 1
--    - Day 30 (Jan 30) gets bit position 1: 2^1 = 2
--    - Day 1 (Jan 1) gets bit position 30: 2^30 = 1073741824
-- 4. Sum all the bit values to create a single integer representing the entire month
--
-- Benefits of this encoding:
--   - 32-bit integer represents 32 days of activity (1 month)
--   - Much more storage efficient than storing arrays
--   - Can use bitwise operations for fast analytics (BIT_COUNT for active days)
--   - Easy to visualize activity patterns when converted to binary string
--
-- Output columns:
--   - datelist_int: The compressed integer representation
--   - datelist_int_binary: Binary string visualization (e.g., '10101010...')
--   - cnt_active_days: Count of 1s in the binary (total active days)

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