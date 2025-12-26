-- TASK 3: Incremental cumulative query to build device_activity_datelist
--
-- This query implements the "yesterday + today" incremental pattern:
-- 1. Fetches yesterday's cumulative snapshot (all historical activity up to yesterday)
-- 2. Extracts today's new events from the events table
-- 3. Merges them using FULL OUTER JOIN to handle:
--    - Existing users who are active today (append today's date to their array)
--    - Existing users who are inactive today (carry forward their existing array)
--    - New users appearing for the first time (create new array with just today's date)
--
-- The CASE statement builds the cumulative array:
--   - If no history exists: Start fresh with today's date
--   - If user inactive today: Carry forward yesterday's array unchanged
--   - If user active today: Prepend today's date to the existing array
--
-- This approach is idempotent and can be run daily to incrementally build the cumulative table

INSERT INTO user_devices_cumulated
WITH yesterday AS (SELECT *
                   FROM user_devices_cumulated
                   WHERE date = DATE('2023-01-30')),

     today AS (SELECT e.user_id,
                      DATE(CAST(e.event_time AS TIMESTAMP)) AS date_active,
                      d.browser_type                        AS browser_type
               FROM events e
                        LEFT JOIN devices d
                                  ON e.device_id = d.device_id
               WHERE DATE(CAST(e.event_time AS TIMESTAMP)) = DATE('2023-01-31')
                 AND e.user_id IS NOT NULL
                 AND d.browser_type IS NOT NULL
               GROUP BY e.user_id,
                        DATE(CAST(e.event_time AS TIMESTAMP)),
                        d.browser_type)

SELECT COALESCE(t.user_id, y.user_id)                     AS user_id,
       CASE
           WHEN y.device_activity_datelist IS NULL THEN ARRAY [t.date_active]
           WHEN t.date_active IS NULL THEN y.device_activity_datelist
           ELSE ARRAY [t.date_active] || y.device_activity_datelist
           END                                            AS device_activity_datelist,
       COALESCE(t.browser_type, y.browser_type)           AS browser_type,
       COALESCE(t.date_active, y.date + INTERVAL '1 day') AS date
FROM today t
         FULL OUTER JOIN yesterday y
                         ON t.user_id = y.user_id
                             AND t.browser_type = y.browser_type
ON CONFLICT DO NOTHING;
