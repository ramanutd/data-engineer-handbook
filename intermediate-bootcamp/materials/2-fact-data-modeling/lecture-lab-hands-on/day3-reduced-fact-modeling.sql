-- ==================================================================================
-- REDUCED FACT MODELING: Array-Based Metrics
-- ==================================================================================
-- This demonstrates a powerful pattern for storing time-series metrics efficiently
--
-- TRADITIONAL APPROACH (One row per user per day):
-- | user_id | date       | metric_name | value |
-- |---------|------------|-------------|-------|
-- | 123     | 2023-01-01 | site_hits   | 5     |
-- | 123     | 2023-01-02 | site_hits   | 3     |
-- | 123     | 2023-01-03 | site_hits   | 8     |
-- Result: 3 rows for 3 days
--
-- ARRAY APPROACH (One row per user per month):
-- | user_id | month_start | metric_name | metric_array |
-- |---------|-------------|-------------|--------------|
-- | 123     | 2023-01-01  | site_hits   | [5, 3, 8]    |
-- Result: 1 row for 3 days
--
-- BENEFITS:
-- 1. COMPRESSION: 90%+ reduction in row count (31 days → 1 row)
-- 2. FEWER PARTITIONS: Monthly partitions instead of daily (faster queries)
-- 3. TEMPORAL LOCALITY: Related data stored together (better cache utilization)
-- 4. EFFICIENT AGGREGATION: Can sum entire arrays at once
-- 5. REDUCED I/O: Read far fewer rows for same data
--
-- TRADE-OFFS:
-- - Slightly more complex queries (array indexing)
-- - Fixed granularity (daily within month)
-- - Array size limits (PostgreSQL: 1GB per field, practical: ~1000 elements)
--
-- USE CASES:
-- - Daily metrics that are queried by month/week
-- - High-cardinality dimensions (millions of users)
-- - Time-series data with regular intervals
-- ==================================================================================

CREATE TABLE array_metrics
(
    user_id      NUMERIC,
    month_start  DATE,   -- First day of the month (partition key in production)
    metric_name  TEXT,   -- Allows multiple metrics per user (site_hits, purchases, etc.)
    metric_array REAL[], -- Array where index = day of month, value = metric for that day
    PRIMARY KEY (user_id, month_start, metric_name)
);



-- ==================================================================================
-- INCREMENTAL ARRAY BUILDING: Daily Append Pattern
-- ==================================================================================
-- This INSERT implements the "yesterday + today" pattern for array metrics
--
-- THE ALGORITHM:
-- 1. Calculate today's metrics (daily_aggregate)
-- 2. Load yesterday's array state (yesterday_array)
-- 3. Merge them:
--    - Existing user: Append today's value to array
--    - New user: Create array with zeros for past days + today's value
-- 4. Use ON CONFLICT to handle idempotency (can re-run safely)
--
-- EXAMPLE WALKTHROUGH:
-- Day 1 (2023-01-01): User 123 has 5 site hits
--   Result: [5]
--
-- Day 2 (2023-01-02): User 123 has 3 site hits
--   Result: [5, 3]
--
-- Day 4 (2023-01-04): User 123 has 8 site hits, but we missed day 3
--   Result: [5, 3, 0, 8]  ← Notice the 0 for the missing day
--
--  4 (2023-01-04): User 456 first appears with 2 site hits (joined on day 4)
--   Result: [0, 0, 0, 2]  ← ARRAY_FILL creates zeros for days 1-3
-- ==================================================================================

INSERT INTO array_metrics
WITH daily_aggregate AS (
    -- STEP 1: Calculate today's metrics
    -- Count site hits per user for a specific date
    SELECT user_id,
           DATE(event_time) AS date,
           COUNT(1)         AS num_site_hits
    FROM events
    WHERE DATE(event_time) = DATE('2023-01-04') -- Process one day at a time (increment this)
      AND user_id IS NOT NULL
    GROUP BY user_id, DATE(event_time)),
     yesterday_array AS (
         -- STEP 2: Get the current state of arrays for this month
         -- This contains the array built from previous days
         SELECT *
         FROM array_metrics
         WHERE month_start = DATE('2023-01-01') -- Start of current month
     )

SELECT COALESCE(da.user_id, ya.user_id)                       AS user_id,
       COALESCE(ya.month_start, DATE_TRUNC('month', da.date)) AS month_start,
       'site_hits'                                            AS metric_name,
       CASE
           -- CASE 1: User exists with array - append today's value
           -- Example: [5, 3] || [8] = [5, 3, 8]
           WHEN ya.metric_array IS NOT NULL THEN
               ya.metric_array || ARRAY [COALESCE(da.num_site_hits, 0)]
           -- CASE 2: New user (no existing array) - create array with leading zeros
           -- ARRAY_FILL creates an array of zeros for all days before today
           -- da.date - DATE(DATE_TRUNC('month', da.date)) calculates day of month (0-indexed)
           -- Example: If today is Jan 4 (day 3 in 0-indexed), create [0, 0, 0, 8]
           WHEN ya.metric_array IS NULL THEN
               ARRAY_FILL(0, ARRAY [COALESCE(da.date - DATE(DATE_TRUNC('month', da.date)), 0)])
                   || ARRAY [COALESCE(da.num_site_hits, 0)]
           END                                                AS metric_array
FROM daily_aggregate da
         FULL OUTER JOIN yesterday_array ya
                         ON da.user_id = ya.user_id
-- ON CONFLICT makes this query IDEMPOTENT
-- If you run this query twice for the same day, it will update (not duplicate)
-- This is crucial for data pipeline reliability
ON CONFLICT (user_id, month_start, metric_name)
    DO UPDATE SET metric_array = EXCLUDED.metric_array;


-- ==================================================================================
-- DATA MANAGEMENT & VERIFICATION
-- ==================================================================================

-- Clear table for fresh start (useful for testing/development)
DELETE
FROM array_metrics;

-- View all data in the array_metrics table
-- Each row represents one user's metrics for one month
SELECT *
FROM array_metrics;

-- ==================================================================================
-- DATA QUALITY CHECK: Verify Array Length Uniformity
-- ==================================================================================
-- Within a given month, all users should have the same array length
-- This ensures data consistency and makes aggregations reliable
--
-- EXAMPLE OUTPUT after processing 4 days:
-- | cardinality | count |
-- |-------------|-------|
-- | 4           | 1523  |  ← All 1523 users have 4-element arrays
--
-- WHY THIS MATTERS:
-- - Ensures no user is missing days (all arrays same length)
-- - Makes index-based queries safe (metric_array[3] exists for all)
-- - Validates that ARRAY_FILL logic worked correctly for new users
--
-- IF YOU SEE MULTIPLE CARDINALITIES:
-- - Bug in the ARRAY_FILL logic
-- - Data from different months got mixed up
-- - Manual data corruption
-- ==================================================================================

-- Check that every user has the same number of values in their array for a given month
SELECT CARDINALITY(metric_array) AS array_length, -- Number of elements in array
       COUNT(1)                  AS num_users     -- How many users have this length
FROM array_metrics
GROUP BY 1;


-- ==================================================================================
-- ARRAY AGGREGATION: Summing Across All Users
-- ==================================================================================
-- This query demonstrates how to aggregate array metrics
-- Each position in the array represents a specific day
--
-- HOW IT WORKS:
-- - metric_array[1]: Day 1 values for all users
-- - metric_array[2]: Day 2 values for all users
-- - SUM(metric_array[1]): Total site hits across all users on day 1
--
-- EXAMPLE:
-- User 123: [5, 3, 8]
-- User 456: [2, 0, 4]
-- User 789: [1, 1, 1]
-- Result: [8, 4, 13]  ← Sum of each position
--
-- LIMITATION:
-- - Must manually specify each array index (not dynamic)
-- - Need to know array length in advance
-- - Must update query when adding new days
-- ==================================================================================

SELECT metric_name,
       month_start,
       ARRAY [SUM(metric_array[1]), -- Total for day 1
           SUM(metric_array[2]), -- Total for day 2
           SUM(metric_array[3])] -- Total for day 3
FROM array_metrics
GROUP BY metric_name, month_start;

-- ==================================================================================
-- RECONSTRUCTING DAILY FACTS: Array to Row Conversion
-- ==================================================================================
-- This query "explodes" array metrics back into traditional daily rows
-- Useful for:
-- - Compatibility with BI tools that expect daily rows
-- - Ad-hoc analysis requiring standard SQL operations
-- - Joining with other daily fact tables
--
-- THE PROCESS:
-- 1. Aggregate arrays across all users (one array per month)
-- 2. UNNEST to convert array → rows (one row per day)
-- 3. Use WITH ORDINALITY to get array position as index (1-based)
-- 4. Calculate actual date from month_start + index
--
-- UNNEST WITH ORDINALITY EXPLAINED:
-- - UNNEST([8, 4, 13]) produces 3 rows with values 8, 4, 13
-- - WITH ORDINALITY adds a sequential index: (8, 1), (4, 2), (13, 3)
-- - We subtract 1 from index because day 1 is at month_start + 0 days
--
-- EXAMPLE:
-- Input:  {site_hits, 2023-01-01, [8, 4, 13]}
-- Output:
-- | metric_name | date       | value |
-- |-------------|------------|-------|
-- | site_hits   | 2023-01-01 | 8     |  ← month_start + (1-1) days
-- | site_hits   | 2023-01-02 | 4     |  ← month_start + (2-1) days
-- | site_hits   | 2023-01-03 | 13    |  ← month_start + (3-1) days
--
-- PERFORMANCE NOTE:
-- This is the opposite of compression - creates many rows from few
-- Do this AFTER filtering/aggregating to minimize row explosion
-- ==================================================================================

-- Convert monthly array metrics back to daily aggregate format
WITH agg AS (
    -- STEP 1: Aggregate arrays across all users
    -- Create one summed array per metric per month
    SELECT metric_name,
           month_start,
           ARRAY [
               SUM(metric_array[1]),
               SUM(metric_array[2]),
               SUM(metric_array[3]),
               SUM(metric_array[4]) -- Extend this array as you process more days
               ] AS summed_array
    FROM array_metrics
    GROUP BY metric_name, month_start)

-- STEP 2: UNNEST to convert array positions to individual date rows
SELECT metric_name,
       -- Calculate actual date: month_start + (index - 1) days
       -- CAST chain: index → TEXT → concatenate with ' day' → INTERVAL
       month_start + CAST(CAST(index - 1 AS TEXT) || ' day' AS INTERVAL) AS date,
       elem                                                              AS value
FROM agg
         -- CROSS JOIN UNNEST creates cartesian product: one row per array element
         -- WITH ORDINALITY adds index (1, 2, 3, ...) to track array position
         CROSS JOIN UNNEST(agg.summed_array)
    WITH ORDINALITY AS a(elem, index);

-- ==================================================================================
-- KEY TAKEAWAYS & BEST PRACTICES
-- ==================================================================================
/*
WHEN TO USE ARRAY METRICS:
✅ High cardinality dimensions (millions of users/devices)
✅ Regular time intervals (daily/hourly within fixed period)
✅ Queries typically aggregate by week/month (not individual days)
✅ Write-heavy workloads (fewer rows to update)

WHEN NOT TO USE:
❌ Irregular time intervals (sporadic events)
❌ Queries frequently need specific individual days
❌ Need to join daily data with other daily tables (unnest overhead)
❌ Array would be too large (>1000 elements gets unwieldy)

PRODUCTION CONSIDERATIONS:
1. PARTITION BY month_start for efficient queries
2. Add indexes on (user_id, month_start) for lookups
3. Consider separate tables per metric_name if many metrics
4. Monitor array sizes - consider chunking if approaching limits
5. Implement data retention policies (drop old month partitions)

ARRAY SIZE LIMITS:
- PostgreSQL: 1GB per field (theoretical)
- Practical: Keep arrays under 1000 elements for performance
- Daily metrics → monthly arrays = 31 elements (perfect fit)
- Hourly metrics → daily arrays = 24 elements (good)
- Hourly metrics → monthly arrays = 744 elements (approaching limit)

ALTERNATIVE APPROACHES:
- Array of structs: Store multiple metrics per element
  Example: [(date: 2023-01-01, hits: 5, revenue: 10), ...]
- Nested arrays: 2D arrays for multiple dimensions
  Example: [[hits_by_hour_day1], [hits_by_hour_day2], ...]
- JSON/JSONB: More flexible but slower and less type-safe
*/
