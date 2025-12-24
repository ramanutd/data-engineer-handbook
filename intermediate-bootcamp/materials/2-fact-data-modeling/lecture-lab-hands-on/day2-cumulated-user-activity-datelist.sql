-- ==================================================================================
-- EXPLORATORY QUERIES: Understanding the source data
-- ==================================================================================

-- View all events to understand the data structure
SELECT *
FROM events;

-- Find the date range of events in the dataset
-- This helps determine how many days we need to backfill
SELECT MIN(event_time),
       MAX(event_time)
FROM events;

-- ==================================================================================
-- TABLE DEFINITION: users_cumulated
-- ==================================================================================
-- This is a CUMULATIVE table that stores user activity history incrementally.
-- Each row represents a user's complete activity history up to a specific date.
-- This design allows us to build history day-by-day without reprocessing all data.
-- ==================================================================================

CREATE TABLE users_cumulated
(
    user_id      TEXT,   -- Type BIGINT threw ERROR: bigint out of range
    dates_active DATE[], -- the list of dates in the past when the user was active
    date         DATE,   -- the current date for the user (snapshot date)
    PRIMARY KEY (user_id, date)
);

-- ==================================================================================
-- INCREMENTAL INSERT PATTERN: Building cumulative history day-by-day
-- ==================================================================================
-- This query implements the "yesterday + today" pattern for cumulative tables:
-- 1. Get yesterday's complete history for each user
-- 2. Get today's new activity
-- 3. Merge them together to create today's updated history
--
-- This approach is:
-- - EFFICIENT: Only processes new data, not all historical data
-- - IDEMPOTENT: Can be re-run for the same date without duplicates
-- - INCREMENTAL: Builds on previous day's results
-- ==================================================================================

INSERT INTO users_cumulated
WITH yesterday AS (
    -- Get the previous day's cumulative history for all users
    -- This contains all dates_active up to 2023-01-30
    SELECT *
    FROM users_cumulated
    WHERE date = DATE('2023-01-30') -- yesterday date started from 2022-12-31
),
     today AS (
         -- Extract today's active users from the events table
         -- This identifies which users had activity on 2023-01-31
         SELECT CAST(user_id AS TEXT)               AS user_id,
                DATE(CAST(event_time AS TIMESTAMP)) AS date_active
         FROM events
         WHERE DATE(CAST(event_time AS TIMESTAMP)) = DATE('2023-01-31') -- today date started from 2023-01-01
           AND user_id IS NOT NULL
         GROUP BY user_id,
                  DATE(CAST(event_time AS TIMESTAMP)))

SELECT COALESCE(t.user_id, y.user_id)                     AS user_id,
       -- Merge yesterday's history with today's activity
       CASE
           -- New user: first time seeing this user (only in today, not in yesterday)
           WHEN y.dates_active IS NULL THEN ARRAY [t.date_active]
           -- Inactive user: user existed yesterday but not active today
           WHEN t.date_active IS NULL THEN y.dates_active
           -- Active user: user was active today, prepend today's date to history
           -- Using || operator to concatenate arrays: [today] + [previous dates]
           ELSE ARRAY [t.date_active] || y.dates_active
           END                                            AS dates_active,
       -- Set the snapshot date (either today's activity date, or move yesterday forward by 1 day)
       COALESCE(t.date_active, y.date + INTERVAL '1 day') AS date
FROM today t
         -- FULL OUTER JOIN ensures we capture:
         -- - Users active today (in 't')
         -- - Users with history but not active today (in 'y')
         -- - Users active today who are new (only in 't')
         FULL OUTER JOIN yesterday y
                         ON t.user_id = y.user_id;

-- Verify the inserted data from 2023-01-01 to 2023-01-31
SELECT *
FROM users_cumulated
WHERE date = '2023-01-31';

-- ==================================================================================
-- CONVERTING ARRAY-BASED HISTORY TO BIT-BASED HISTORY
-- ==================================================================================
-- The following queries show the step-by-step transformation from:
-- dates_active ARRAY → binary bitmap representation
--
-- WHY? Bit-based representation is more efficient for:
-- - Storage: 1 integer vs array of dates
-- - Querying: Fast bitwise operations
-- - Analysis: Easy to calculate metrics like "active last 7 days"
-- ==================================================================================

-- Generate a date list from 2023-01-01 to 2023-01-31
-- GENERATE_SERIES creates one row per day in the range
SELECT *
FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day');

-- Combine the date list with a specific user from users_cumulated
-- to see all the dates and the user's activity on those dates
-- CROSS JOIN creates a cartesian product: every user × every date
-- Result: 31 rows (one per day) for the specific user
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
-- The @> operator checks "array contains element"
-- dates_active @> ARRAY[DATE(series_date)] returns TRUE if user was active on that date
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date)

SELECT dates_active @> ARRAY [DATE(series_date)] AS was_active_on_date,
       *
FROM users
         CROSS JOIN series
WHERE user_id = '439578290726747300';


-- Calculate the difference in days between each date in the series and the current date
-- This shows how many days ago each date in the series was
-- Example: if date = 2023-01-31 and series_date = 2023-01-15, then difference = 16 days
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date)

SELECT date - DATE(series_date) AS days_ago,
       *
FROM users
         CROSS JOIN series
WHERE user_id = '439578290726747300';


-- Calculate a datelist integer value based on user activity and date difference
-- This is the KEY step: converting TRUE/FALSE activity to a power-of-2 value
-- Each date gets a unique power of 2 based on how long ago it was
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


-- Datelist integer value as BIT(32) - visualizing individual day bits
-- This query shows each day as a separate BIT(32) value (only ONE bit set per row)
-- Useful for understanding how individual dates map to bit positions
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

-- Sum the datelist integer values to get the final datelist integer and BIT(32) values
-- IMPORTANT: We DON'T cast to BIT(32) before summing because:
-- - BIT types can't be summed directly
-- - We need to sum as numbers first, THEN convert to BIT(32)
-- - The sum combines all active days into a single integer where each bit = one day
--
-- After removing the user filter, this aggregates ALL users at once
WITH users AS (SELECT *
               FROM users_cumulated
               WHERE date = '2023-01-31'),
     series AS (SELECT *
                FROM GENERATE_SERIES(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS series_date),
     place_holder_ints AS (SELECT CASE
                                      WHEN dates_active @> ARRAY [DATE(series_date)]
                                          THEN POW(2, 32 - (date - DATE(series_date))) -- keep as numeric for summation
                                      ELSE 0
                                      END AS placeholder_int_value,
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

-- ==================================================================================
-- FINAL QUERY: Calculate Activity Metrics Using Bitwise Operations
-- ==================================================================================
-- This query demonstrates how to use bit masks to extract different time windows
-- from the activity bitmap and calculate meaningful user engagement metrics.
--
-- BIT MASKS EXPLAINED:
-- - '11111111111111111111111111111111' = All 32 bits (monthly)
-- - '11111110000000000000000000000000' = First 7 bits (weekly - last 7 days)
-- - '10000000000000000000000000000000' = First bit only (daily - today)
--
-- BITWISE & OPERATION:
-- The & operator performs a logical AND on each bit position.
-- Only bits that are 1 in BOTH the mask and the user's activity remain as 1.
--
-- Example: User active on days 1, 2, and 5 from today
--   User bitmap:  11001000000000000000000000000000
--   Weekly mask:  11111110000000000000000000000000
--   Result:       11001000000000000000000000000000  (all activities in last 7 days)
--
-- BIT_COUNT():
-- Counts how many bits are set to 1 in the result.
-- This tells us how many days the user was active in that time window.
-- ==================================================================================

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
       -- MONTHLY METRICS (all 31 days)
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))                AS datelist_bit_value_monthly,
       BIT_COUNT(CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32)))     AS user_monthly_active_days,
       BIT_COUNT(CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_monthly_active,

       -- WEEKLY METRICS (last 7 days)
       -- Using '11111110000000000000000000000000' mask to isolate first 7 bits
       CAST(('11111110000000000000000000000000') AS BIT(32)) &
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))                AS datelist_bit_value_weekly,
       BIT_COUNT(CAST(('11111110000000000000000000000000') AS BIT(32)) &
                 CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_weekly_active,

       -- DAILY METRICS (today only)
       -- Using '10000000000000000000000000000000' mask to isolate first bit only
       CAST(('10000000000000000000000000000000') AS BIT(32)) &
       CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))                AS datelist_bit_value_today,
       BIT_COUNT(CAST(('10000000000000000000000000000000') AS BIT(32)) &
                 CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))) > 0 AS dim_is_daily_active
FROM place_holder_ints
GROUP BY user_id;