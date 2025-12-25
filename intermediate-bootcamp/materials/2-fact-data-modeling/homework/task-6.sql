-- TASK 6: Incremental query to build host_activity_datelist
--
-- This query implements the same "yesterday + today" pattern as task-3 but for hosts:
-- 1. Fetches yesterday's cumulative host activity snapshot
-- 2. Extracts today's events grouped by host (any event counts as host activity)
-- 3. Merges using FULL OUTER JOIN to handle:
--    - Hosts that were active today: Append today's date to their activity array
--    - Hosts that were active yesterday but not today: Carry forward their array
--    - New hosts appearing for the first time: Create new array with today's date
--
-- The query treats any user activity on a host as "host activity" for that day
-- Runs daily to incrementally build the cumulative history of host activity patterns

INSERT INTO hosts_cumulated
WITH yesterday AS (SELECT *
                   FROM hosts_cumulated
                   WHERE date = DATE('2023-01-30')),

     today AS (SELECT host,
                      DATE(CAST(event_time AS TIMESTAMP)) AS date_active
               FROM events
               WHERE DATE(CAST(event_time AS TIMESTAMP)) = DATE('2023-01-31')
                 AND user_id IS NOT NULL
               GROUP BY host,
                        DATE(CAST(event_time AS TIMESTAMP)))

SELECT COALESCE(t.host, y.host)                           AS host,
       CASE
           WHEN y.host_activity_datelist IS NULL THEN ARRAY [t.date_active]
           WHEN t.date_active IS NULL THEN y.host_activity_datelist
           ELSE ARRAY [t.date_active] || y.host_activity_datelist
           END                                            AS host_activity_datelist,
       COALESCE(t.date_active, y.date + INTERVAL '1 day') AS date
FROM today t
         FULL OUTER JOIN yesterday y
                         ON t.host = y.host;