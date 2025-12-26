-- TASK 7: DDL for monthly reduced fact table host_activity_reduced
--
-- This table compresses daily host activity into monthly aggregates using arrays.
-- Each array element represents a day in the month, enabling time-series analysis.
--
-- Structure:
--   - host: Website domain being tracked
--   - month_start: First day of the month (e.g., '2023-01-01' for January 2023)
--   - hit_metric: Metric name for hits (set to 'site_hits')
--   - hit_array: Array of daily hit counts [day1_hits, day2_hits, ..., day31_hits]
--   - unique_visitors_metric: Metric name for visitors (set to 'unique_visitors')
--   - unique_visitors_array: Array of daily unique visitor counts per day
--
-- Benefits:
--   - Compact storage: One row per host per month instead of 30+ rows
--   - Fast analytics: Array operations enable efficient trend analysis
--   - Flexible querying: Can slice arrays for week-over-week or day-over-day comparisons

CREATE TABLE host_activity_reduced
(
    host                   TEXT,
    month_start            DATE,
    hit_metric             TEXT,
    hit_array              INTEGER[],
    unique_visitors_metric TEXT,
    unique_visitors_array  INTEGER[],
    PRIMARY KEY (host, month_start, hit_metric, unique_visitors_metric)
);