SELECT *
FROM events;


SELECT MIN(event_time),
       MAX(event_time)
FROM events;

CREATE TABLE users_cumulated
(
    user_id      TEXT,   -- Type BIGINT threw ERROR: bigint out of range
    dates_active DATE[], -- the list of dates in the past when the user was active
    date         DATE,   -- the current date for the user
    PRIMARY KEY (user_id, date)
);

INSERT INTO users_cumulated
WITH yesterday AS (SELECT *
                   FROM users_cumulated
                   WHERE date = DATE('2023-01-30')), -- yesterday date started from 2022-12-31
     today AS (SELECT CAST(user_id AS TEXT)               AS user_id,
                      DATE(CAST(event_time AS TIMESTAMP)) AS date_active
               FROM events
               WHERE DATE(CAST(event_time AS TIMESTAMP)) = DATE('2023-01-31') -- today date started from 2023-01-01
                 AND user_id IS NOT NULL
               GROUP BY user_id,
                        DATE(CAST(event_time AS TIMESTAMP)))

SELECT COALESCE(t.user_id, y.user_id)                     AS user_id,
       CASE
           WHEN y.dates_active IS NULL THEN ARRAY [t.date_active]
           WHEN t.date_active IS NULL THEN y.dates_active
           ELSE ARRAY [t.date_active] || y.dates_active
           END                                            AS dates_active,
       COALESCE(t.date_active, y.date + INTERVAL '1 day') AS date
FROM today t
         FULL OUTER JOIN yesterday y
                         ON t.user_id = y.user_id;

-- Verify the inserted data from 2023-01-01 to 2023-01-31
SELECT *
FROM users_cumulated
WHERE date = '2023-01-31';


-- Generate a date list from 2023-01-01 to 2023-01-31
SELECT *
FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day');

-- Combine the date list with a specific user from users_cumulated
-- to see all the dates and the user's activity on those dates
-- for user_id = '439578290726747300'
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date)

SELECT *
FROM users
         CROSS JOIN series
WHERE user_id = '439578290726747300';


-- Check if the user was active on each date from 2023-01-01 to 2023-01-31
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date)

SELECT dates_active @> ARRAY [DATE(series_date)],
       *
FROM users
         CROSS JOIN series
WHERE user_id = '439578290726747300';


-- Calculate the difference in days between each date in the series and the current date
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date)

SELECT date - DATE(series_date),
       *
FROM users
         CROSS JOIN series
WHERE user_id = '439578290726747300';


-- calculate a datelist integer value based on user activity and date difference
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date)

SELECT CASE
           WHEN dates_active @> ARRAY [DATE(series_date)] -- check if user was active on that date in the series
               THEN POW(2, 32 - (date - DATE(series_date))) -- left most bit is for the most recent date
           ELSE 0
           END AS placeholder_int_value,
       *
FROM users
         CROSS JOIN series
WHERE user_id = '439578290726747300';


-- datelist integer value as BIT(32)
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date),
     place_holder_ints AS (SELECT CAST(CASE
                                           WHEN dates_active @> ARRAY [DATE(series_date)]
                                               THEN CAST(POW(2, 32 - (date - DATE(series_date))) AS BIGINT)
                                           ELSE 0
         END AS BIT(32)) AS placeholder_int_value,
                                  *
                           FROM users
                                    CROSS JOIN series
                           WHERE user_id = '439578290726747300')

SELECT *
FROM place_holder_ints;

-- sum the datelist integer values to get the final datelist integer and BIT(32) values
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date),
     place_holder_ints AS (SELECT CASE
                                      WHEN dates_active @> ARRAY [DATE(series_date)]
                                          THEN POW(2, 32 - (date - DATE(series_date))) -- remove CAST BIGINT as well since BIT(32) is removed
                                      ELSE 0
                                      END AS placeholder_int_value, -- remove CAST to BIT(32) here to sum BIGINT values as single value for last 31 days
                                  *
                           FROM users
                                    CROSS JOIN series
         -- WHERE user_id = '439578290726747300' -- remove user filter to get all users
     )

SELECT user_id,
       SUM(placeholder_int_value)                                  AS datelist_int_value,
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32)) AS datelist_bit_value
FROM place_holder_ints
GROUP BY user_id;


/*
 * ==================================================================================
 * EXPLANATION OF POW(2, 32 - (date - DATE(series_date)))
 * ==================================================================================
 *
 * This formula creates a binary bitmap to track user activity across multiple dates.
 * Each date gets a unique power of 2, representing a specific bit position.
 *
 * FORMULA BREAKDOWN:
 * ------------------
 * - date: The current reference date (e.g., 2023-01-31)
 * - DATE(series_date): A date from the series (e.g., 2023-01-15)
 * - date - DATE(series_date): Number of days between them (e.g., 16 days ago)
 * - 32 - (date - DATE(series_date)): The bit position from left (e.g., 32 - 16 = 16)
 * - POW(2, 16): The power of 2 for that position (e.g., 65,536)
 *
 * WHY USE THIS APPROACH?
 * ----------------------
 * Instead of storing an array of dates, we can store a single integer where each bit
 * represents whether the user was active on a specific day. This is memory-efficient
 * and allows fast bitwise operations.
 *
 * EXAMPLE WITH date = 2023-01-31:
 * --------------------------------
 * | series_date | Days Ago | Calculation      | Bit Position | POW(2, x)     | Binary (32-bit)                      |
 * |-------------|----------|------------------|--------------|---------------|--------------------------------------|
 * | 2023-01-31  | 0        | 32 - (31-31)     | 32           | 2^32          | 100000000000000000000000000000000    |
 * | 2023-01-30  | 1        | 32 - (31-30)     | 31           | 2^31          | 010000000000000000000000000000000    |
 * | 2023-01-29  | 2        | 32 - (31-29)     | 30           | 2^30          | 001000000000000000000000000000000    |
 * | 2023-01-15  | 16       | 32 - (31-15)     | 16           | 2^16 = 65,536 | 000000000000000010000000000000000    |
 * | 2023-01-01  | 30       | 32 - (31-1)      | 2            | 2^2 = 4       | 000000000000000000000000000000100    |
 *
 * CONCRETE EXAMPLE:
 * -----------------
 * If a user was active on 2023-01-31, 2023-01-30, and 2023-01-15:
 *
 * Step 1: Calculate individual values
 *   - 2023-01-31: POW(2, 32) = 4,294,967,296
 *   - 2023-01-30: POW(2, 31) = 2,147,483,648
 *   - 2023-01-15: POW(2, 16) = 65,536
 *
 * Step 2: Sum them up
 *   Total = 4,294,967,296 + 2,147,483,648 + 65,536 = 6,442,516,480
 *
 * Step 3: Convert to BIT(32) binary
 *   Binary: 11000000000000001000000000000000
 *   Reading from left to right:
 *   - Bit 32 (1) = Active on 2023-01-31 ✓
 *   - Bit 31 (1) = Active on 2023-01-30 ✓
 *   - Bit 30 (0) = Not active on 2023-01-29
 *   - ...
 *   - Bit 16 (1) = Active on 2023-01-15 ✓
 *   - ...
 *   - Bit 1 (0) = Not active on 2023-01-01
 *
 * KEY INSIGHT:
 * ------------
 * The leftmost bit (position 32) represents the most recent date.
 * When we SUM all the POW(2, ...) values, each bit in the resulting integer
 * tells us if the user was active on that specific day.
 *
 * This allows us to:
 * - Store 31 days of activity in a single integer
 * - Use bitwise operations to quickly check activity patterns
 * - Calculate metrics like "active days in last week" using bit manipulation
*/

WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date),
     place_holder_ints AS (SELECT CASE
                                      WHEN dates_active @> ARRAY [DATE(series_date)]
                                          THEN POW(2, 32 - (date - DATE(series_date)))
                                      ELSE 0
                                      END AS placeholder_int_value,
                                  *
                           FROM users
                                    CROSS JOIN series)


-- Final aggregation to get user activity metrics
SELECT user_id,
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))                AS datelist_bit_value_monthly,
       BIT_COUNT(CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32)))     AS user_monthly_active_days,
       BIT_COUNT(CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_monthly_active,

       CAST(('11111110000000000000000000000000') AS BIT(32)) & -- BIT and operation to isolate last 7 days
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))                AS datelist_bit_value_weekly,
       BIT_COUNT(CAST(('11111110000000000000000000000000') AS BIT(32)) &
                 CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_weekly_active,

       CAST(('10000000000000000000000000000000') AS BIT(32)) & -- BIT and operation to isolate today
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))                AS datelist_bit_value_today,
       BIT_COUNT(CAST(('10000000000000000000000000000000') AS BIT(32)) &
                 CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_daily_active
FROM place_holder_ints
GROUP BY user_id;