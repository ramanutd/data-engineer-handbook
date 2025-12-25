-- TASK 8: Incremental query to load host_activity_reduced day-by-day
--
-- This query builds monthly metric arrays incrementally by appending each day's metrics:
-- 1. Aggregates today's events: Counts total hits and unique visitors per host
-- 2. Fetches yesterday's array from the reduced table (for the current month)
-- 3. Appends today's metrics to the existing arrays
--
-- Array Building Logic:
--   - If array exists: Append today's value (e.g., [1,2,3] becomes [1,2,3,4])
--   - If array is NULL (first day): Create array with leading zeros for prior days
--     Example: Day 5 starts as [0,0,0,0,5] to align with the day of month
--
-- ON CONFLICT: Handles reruns by updating arrays if the record already exists
-- This enables idempotent daily runs and supports backfilling historical data

INSERT INTO host_activity_reduced
WITH daily_aggregate AS (SELECT host,
                                DATE(event_time)        AS date,
                                COUNT(1)                AS hits,
                                COUNT(DISTINCT user_id) AS unique_visitors
                         FROM events
                         WHERE DATE(event_time) = '2023-01-31'
                           AND user_id IS NOT NULL
                         GROUP BY host,
                                  DATE(event_time)),
     yesterday_array AS (SELECT *
                         FROM host_activity_reduced
                         WHERE month_start = '2023-01-01')

SELECT COALESCE(da.host, ya.host)                                   AS host,
       COALESCE(ya.month_start, DATE(DATE_TRUNC('month', da.date))) AS month_start,
       'site_hits'                                                  AS hit_metric,
       CASE
           WHEN ya.hit_array IS NOT NULL
               THEN ya.hit_array || ARRAY [COALESCE(da.hits, 0)]
           WHEN ya.hit_array IS NULL
               THEN ARRAY_FILL(0, ARRAY [COALESCE(da.date - DATE(DATE_TRUNC('month', da.date)), 0)])
               || ARRAY [COALESCE(da.hits, 0)]
           END                                                      AS hit_array,
       'unique_visitors'                                            AS unique_visitors_metric,
       CASE
           WHEN ya.unique_visitors_array IS NOT NULL
               THEN ya.unique_visitors_array || ARRAY [COALESCE(da.unique_visitors, 0)]
           WHEN ya.unique_visitors_array IS NULL
               THEN ARRAY_FILL(0, ARRAY [COALESCE(da.date - DATE(DATE_TRUNC('month', da.date)), 0)])
               || ARRAY [COALESCE(da.unique_visitors, 0)]
           END                                                      AS unique_visitors_array
FROM daily_aggregate da
         FULL OUTER JOIN yesterday_array ya
                         ON da.host = ya.host
ON CONFLICT (host, month_start, hit_metric, unique_visitors_metric)
    DO UPDATE SET hit_array             = EXCLUDED.hit_array,
                  unique_visitors_array = EXCLUDED.unique_visitors_array;


SELECT *
FROM host_activity_reduced;