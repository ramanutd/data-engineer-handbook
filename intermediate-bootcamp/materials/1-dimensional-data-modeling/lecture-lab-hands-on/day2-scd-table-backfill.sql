-- ==================================================================================
-- PREREQUISITE: Data Setup
-- ==================================================================================
-- Before running this script:
-- 1. Re-create players table using players.sql
-- 2. Backfill data using load_players_table_day2.sql script
-- This ensures the source players table has data from 1996 to 2021
-- ==================================================================================

-- ==================================================================================
-- SCD TYPE 2 TABLE: players_scd
-- ==================================================================================
-- Slowly Changing Dimension (SCD) Type 2 tracks historical changes over time
-- Instead of updating records, we create new rows for each change
--
-- WHAT IS SCD TYPE 2?
-- - Tracks complete history of dimension changes
-- - Each change creates a new row with start_season and end_season
-- - Allows "time travel" queries: "What was player X's status in season Y?"
--
-- EXAMPLE: If a player's scoring_class changes from 'good' → 'star' → 'good'
-- We get 3 rows:
-- | player_name | scoring_class | start_season | end_season |
-- |-------------|---------------|--------------|------------|
-- | LeBron      | good          | 2003         | 2007       |
-- | LeBron      | star          | 2008         | 2018       |
-- | LeBron      | good          | 2019         | 2021       |
--
-- FIELDS:
-- - player_name: The player (dimension key)
-- - scoring_class: Performance tier being tracked
-- - is_active: Whether player is active
-- - start_season: When this state began
-- - end_season: When this state ended
-- - current_season: Snapshot date (for partitioning in production)
--
-- PRIMARY KEY: (player_name, start_season)
-- - Ensures one row per player per change period
-- ==================================================================================

CREATE TABLE players_scd
(
    player_name    TEXT,
    scoring_class  scoring_class,
    is_active      BOOLEAN,
    start_season   INTEGER,
    end_season     INTEGER,
    current_season INTEGER, -- In production, use for data partitioning
    PRIMARY KEY (player_name, start_season)
);

-- ==================================================================================
-- SCD BACKFILL: Complete Historical Analysis
-- ==================================================================================
-- This query processes ALL seasons at once to build the complete SCD history
-- It uses the "streak identification" pattern to group consecutive seasons with same attributes
--
-- THE ALGORITHM (4 STEPS):
-- 1. with_previous: Compare each season with previous season using LAG()
-- 2. with_indicators: Mark rows where changes occurred (1 = change, 0 = no change)
-- 3. with_streaks: Create streak_identifier by cumulative sum of changes
-- 4. Final SELECT: Group consecutive seasons into single SCD rows
--
-- WHY THIS WORKS:
-- - LAG() lets us compare current row with previous row
-- - change_indicator flags when scoring_class or is_active changes
-- - Cumulative SUM creates unique IDs for each "streak" of unchanged values
-- - GROUP BY streak_identifier collapses consecutive seasons into one row
--
-- EXAMPLE:
-- | season | scoring_class | prev | change | streak_id |
-- |--------|---------------|------|--------|-----------|
-- | 2003   | good          | NULL | 0      | 0         | ← Start
-- | 2004   | good          | good | 0      | 0         | ← Same streak
-- | 2005   | star          | good | 1      | 1         | ← Change!
-- | 2006   | star          | star | 0      | 1         | ← Same streak
-- | 2007   | good          | star | 1      | 2         | ← Change!
--
-- Result after GROUP BY:
-- | scoring_class | start_season | end_season | streak_id |
-- |---------------|--------------|------------|-----------|
-- | good          | 2003         | 2004       | 0         |
-- | star          | 2005         | 2006       | 1         |
-- | good          | 2007         | 2007       | 2         |
-- ==================================================================================

INSERT INTO players_scd
WITH with_previous AS (
    -- STEP 1: Get previous season's values using LAG window function
    -- LAG(column, offset) returns the value from the row 'offset' rows before current
    SELECT player_name,
           current_season,
           scoring_class,
           is_active,
           LAG(scoring_class, 1) OVER (PARTITION BY player_name ORDER BY current_season) AS prev_scoring_class,
           LAG(is_active, 1) OVER (PARTITION BY player_name ORDER BY current_season)     AS prev_is_active
    FROM players
    WHERE current_season <= 2021 -- Process seasons up to 2021 (increment for new seasons)
),
     with_indicators AS (
         -- STEP 2: Mark rows where changes occurred
         -- If any tracked dimension changed, set indicator to 1
         SELECT *,
                CASE
                    WHEN scoring_class <> prev_scoring_class THEN 1 -- Performance tier changed
                    WHEN is_active <> prev_is_active THEN 1 -- Activity status changed
                    ELSE 0 -- No change
                    END AS change_indicator
         FROM with_previous),
     with_streaks AS (
         -- STEP 3: Create streak identifiers using cumulative sum
         -- Each time change_indicator = 1, the sum increments, creating a new streak ID
         -- All rows with same streak_identifier belong to the same SCD period
         SELECT *,
                SUM(change_indicator) OVER (PARTITION BY player_name ORDER BY current_season) AS streak_identifier
         FROM with_indicators)

-- STEP 4: Collapse consecutive seasons into SCD rows
-- GROUP BY streak_identifier to combine all seasons in each streak
-- MIN(current_season) = start of the period
-- MAX(current_season) = end of the period
SELECT player_name,
       scoring_class,
       is_active,
       MIN(current_season) AS start_season,  -- First season in this streak
       MAX(current_season) AS end_season,    -- Last season in this streak
       2021                AS current_season -- Snapshot date (increment for new seasons)
FROM with_streaks
GROUP BY player_name, streak_identifier, is_active, scoring_class
ORDER BY player_name, streak_identifier;

-- ==================================================================================
-- SCALABILITY CONSIDERATIONS & LIMITATIONS
-- ==================================================================================
/*
⚠️ WARNING: This backfill approach has scalability limitations

PROBLEMS AT SCALE:
1. MEMORY PRESSURE: Window functions (LAG, SUM OVER) require sorting entire
   partition in memory. For players with many seasons, this can be expensive.

2. DATA SKEW: Players who change frequently create many small streaks
   - More streaks = higher cardinality in GROUP BY
   - All data for one player goes to one node (partition by player_name)
   - That node can run out of memory

3. CARDINALITY EXPLOSION: If dimensions change every season (not "slowly" changing),
   the number of rows approaches the original table size (no compression)

WHEN THIS WORKS:
- Millions of entities (like Airbnb users/listings)
- Dimensions that truly change slowly (few changes per entity)
- Distributed systems with adequate memory per node

WHEN THIS FAILS:
- Billions of entities (like Facebook users)
- Frequently changing dimensions (defeats "slowly changing" purpose)
- Memory-constrained environments

ALTERNATIVES FOR LARGER SCALE:
- Use incremental SCD approach (see day2-scd-table-incremental.sql)
- Process in batches by player_name ranges
- Use Spark with repartitioning to distribute skewed players
- Consider SCD Type 1 (just update) if history isn't critical
- Use change data capture (CDC) patterns instead
*/