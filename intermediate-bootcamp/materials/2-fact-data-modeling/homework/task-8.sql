-- TASK 8: Incremental query to load host_activity_reduced day-by-day
--
-- This query builds monthly metric arrays incrementally by appending each day's metrics.
-- It is fully idempotent - safe to re-run multiple times for the same day without duplicating data.
--
-- Query Structure:
-- 1. params CTE: Defines the processing date, month_start, and day_of_month as constants
-- 2. daily_aggregate: Aggregates today's events (total hits and unique visitors per host)
-- 3. yesterday_array: Fetches existing array from the reduced table for the current month
-- 4. Main SELECT: Merges today's metrics with existing arrays
--
-- Array Building Logic (with idempotency):
--   - If array is NULL (first day or new host):
--       Create array with leading zeros for prior days + today's value
--       Example: Day 5 → [0,0,0,0,5]
--   - If array length = day_of_month - 1 (expected state):
--       Append today's value to the array (normal incremental case)
--       Example: Day 5 with [0,0,0,0] → [0,0,0,0,5]
--   - If array length != day_of_month - 1 (re-run detected):
--       Keep the existing array unchanged (already has today's data)
--       This prevents duplicate appends on re-runs
--
-- ON CONFLICT: Updates arrays if record exists (handles initial vs incremental inserts)
-- The ARRAY_LENGTH check ensures true idempotency for same-day re-runs

INSERT INTO host_activity_reduced
WITH params AS (SELECT DATE '2023-01-05'                            AS daily_agg_date,
                       DATE_TRUNC('month', DATE '2023-01-05')::DATE AS month_start,
                       EXTRACT(DAY FROM DATE '2023-01-05')::INT     AS daily_agg_day_of_month),

     daily_aggregate AS (SELECT host,
                                DATE(event_time)        AS date,
                                COUNT(*)                AS hits,
                                COUNT(DISTINCT user_id) AS unique_visitors
                         FROM events
                         WHERE DATE(event_time) = (SELECT daily_agg_date FROM params)
                           AND user_id IS NOT NULL
                         GROUP BY host,
                                  DATE(event_time)),

     yesterday_array AS (SELECT *
                         FROM host_activity_reduced
                         WHERE month_start = (SELECT month_start FROM params))

SELECT COALESCE(da.host, ya.host)       AS host,
       (SELECT month_start FROM params) AS month_start,
       'site_hits'                      AS hit_metric,
       CASE
           WHEN ya.hit_array IS NULL
               THEN ARRAY_FILL(0, ARRAY [(SELECT daily_agg_day_of_month FROM params) - 1])
               || ARRAY [COALESCE(da.hits, 0)]
           WHEN ARRAY_LENGTH(ya.hit_array, 1) = (SELECT daily_agg_day_of_month FROM params) - 1
               THEN ya.hit_array
               || ARRAY [COALESCE(da.hits, 0)]
           ELSE
               ya.hit_array
           END                          AS hit_array,
       'unique_visitors'                AS unique_visitors_metric,
       CASE
           WHEN ya.unique_visitors_array IS NULL
               THEN ARRAY_FILL(0, ARRAY [(SELECT daily_agg_day_of_month FROM params) - 1])
               || ARRAY [COALESCE(da.unique_visitors, 0)]
           WHEN ARRAY_LENGTH(ya.unique_visitors_array, 1) = (SELECT daily_agg_day_of_month FROM params) - 1
               THEN ya.unique_visitors_array || ARRAY [COALESCE(da.unique_visitors, 0)]
           ELSE
               ya.unique_visitors_array
           END                          AS unique_visitors_array
FROM daily_aggregate da
         FULL OUTER JOIN yesterday_array ya
                         ON da.host = ya.host
ON CONFLICT (host, month_start, hit_metric, unique_visitors_metric)
    DO UPDATE SET hit_array             = EXCLUDED.hit_array,
                  unique_visitors_array = EXCLUDED.unique_visitors_array;


/*
-- earlier attempt was not idempotent for re-runs on same day and without params CTE
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
*/