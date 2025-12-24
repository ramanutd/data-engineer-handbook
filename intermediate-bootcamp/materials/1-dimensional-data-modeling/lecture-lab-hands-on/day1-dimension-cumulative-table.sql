-- ==================================================================================
-- EXPLORATORY QUERY: Understanding Source Data
-- ==================================================================================
-- View the player_seasons table to understand its structure
-- This is a "snapshot" table with one row per player per season
-- ==================================================================================

SELECT *
FROM player_seasons;

-- ==================================================================================
-- CUSTOM TYPE DEFINITION: season_stats STRUCT
-- ==================================================================================
-- Create a composite type (struct) to hold temporal dimensions for a single season
-- This allows us to store multiple seasons as an array of structs
--
-- WHY USE A STRUCT?
-- - Groups related data together (season, games played, stats)
-- - Enables storing multiple seasons in a single row as an ARRAY
-- - More efficient than creating separate tables or JSON columns
-- - Type-safe: PostgreSQL validates the structure
--
-- FIELDS:
-- - season: The year of the season
-- - gp: Games played
-- - pts: Points per game
-- - reb: Rebounds per game
-- - ast: Assists per game
-- ==================================================================================

CREATE TYPE season_stats AS
(
    season INTEGER,
    gp     INTEGER,
    pts    REAL,
    reb    REAL,
    ast    REAL
);

-- ==================================================================================
-- CUMULATIVE TABLE DESIGN: players
-- ==================================================================================
-- This is a DIMENSIONAL CUMULATIVE table - a key pattern in data engineering
--
-- WHAT IS A CUMULATIVE TABLE?
-- Instead of one row per player per season (like player_seasons),
-- we store one row per player with ALL their seasons as an array.
--
-- BENEFITS:
-- 1. COMPRESSION: Related data stored together compresses better
-- 2. NO JOINS: All player history in one row (no self-joins needed)
-- 3. TEMPORAL QUERIES: Easy to analyze career progression
-- 4. INCREMENTAL: Can be built day-by-day efficiently
--
-- SCHEMA:
-- - Slowly changing dimensions (height, college, etc.): Latest known values
-- - Temporal dimensions (season_stats[]): Complete history as array
-- - current_season: The "as of" date for this snapshot
--
-- PRIMARY KEY: (player_name, current_season)
-- - Ensures one row per player per season snapshot
-- - Allows us to query "what did we know about player X on date Y?"
-- ==================================================================================

CREATE TABLE players
(
    player_name    TEXT,
    height         TEXT,
    college        TEXT,
    country        TEXT,
    draft_year     TEXT,
    draft_round    TEXT,
    draft_number   TEXT,
    season_stats   season_stats[], -- Array of season_stats structs (temporal history)
    current_season INTEGER,        -- The "as of" season for this snapshot
    PRIMARY KEY (player_name, current_season)
);

-- Find the earliest season in the source data
-- This tells us where to start our backfill process
SELECT MIN(season)
FROM player_seasons;

-- ==================================================================================
-- INCREMENTAL INSERT PATTERN: Building Cumulative History
-- ==================================================================================
-- This implements the "yesterday + today" pattern for cumulative tables
--
-- THE ALGORITHM:
-- 1. Load yesterday's complete state (all players with their history up to 2000)
-- 2. Load today's new data (players active in season 2001)
-- 3. Merge them:
--    - New players: Create first entry with season 2001 stats
--    - Active players: Append season 2001 to their history array
--    - Inactive players: Carry forward yesterday's data with incremented current_season
--
-- WHY THIS WORKS:
-- - EFFICIENT: Only processes 2 seasons of data at a time (not full history)
-- - IDEMPOTENT: Can re-run for same date without issues
-- - INCREMENTAL: Each day builds on the previous day
-- - HANDLES GAPS: Players can skip seasons (e.g., retirement, injury)
--
-- KEY TECHNIQUE: FULL OUTER JOIN
-- - Captures players in today (new activity)
-- - Captures players in yesterday (existing history)
-- - Captures players in BOTH (active continuation)
-- ==================================================================================

INSERT INTO players
WITH yesterday AS (SELECT *
                   FROM players
                   WHERE current_season = 2000), -- Start with season 2000 snapshot
     today AS (SELECT *
               FROM player_seasons
               WHERE season = 2001)              -- Load new season 2001 data

SELECT COALESCE(t.player_name, y.player_name)   AS player_name,
       -- Slowly changing dimensions: Take latest known value (prefer today)
       COALESCE(t.height, y.height)             AS height,
       COALESCE(t.college, y.college)           AS college,
       COALESCE(t.country, y.country)           AS country,
       COALESCE(t.draft_year, y.draft_year)     AS draft_year,
       COALESCE(t.draft_round, y.draft_round)   AS draft_round,
       COALESCE(t.draft_number, y.draft_number) AS draft_number,
       -- Temporal dimension: Build season history array
       CASE
           -- NEW PLAYER: First time seeing this player, create initial array
           WHEN y.season_stats IS NULL THEN ARRAY [ROW (t.season,t.gp,t.pts, t.reb, t.ast)::season_stats]
           -- ACTIVE PLAYER: Player exists and played this season, append to array
           -- Using || operator to concatenate: [old array] + [new season]
           WHEN t.season IS NOT NULL THEN y.season_stats || ARRAY [ROW (t.season, t.gp, t.pts, t.reb, t.ast)::season_stats]
           -- INACTIVE PLAYER: Player exists but didn't play this season, keep old array
           ELSE y.season_stats
           END                                  AS season_stats,
       -- Update current_season to 2001 (or increment if inactive)
       COALESCE(t.season, y.current_season + 1) AS current_season
FROM today t
         FULL OUTER JOIN yesterday y ON t.player_name = y.player_name;

-- ==================================================================================
-- VERIFICATION: Check cumulative table output
-- ==================================================================================

-- Verify all inserted data
SELECT *
FROM players;

-- ==================================================================================
-- SPECIAL CASE: Michael Jordan's Career Gap
-- ==================================================================================
-- Michael Jordan retired in 1997 and returned in 2001
-- This query shows how the cumulative table handles career gaps:
-- - No NULL season_stats entries for retired years (1998-2000)
-- - history array just has a gap between 1997 and 2001
-- - current_season still increments each year (maintaining timeline)
-- ==================================================================================

SELECT *
FROM players
WHERE current_season = 2001
  AND player_name = 'Michael Jordan';

-- ==================================================================================
-- UNNEST PATTERN: Reconstructing Original Table Format
-- ==================================================================================
-- This demonstrates a powerful feature of cumulative design:
-- You can easily "explode" the array back to one row per season
--
-- BENEFITS OF THIS APPROACH:
-- 1. Do all JOINS first (when data is compact)
-- 2. UNNEST at the end (after filtering/joining)
-- 3. Data stays SORTED and maintains COMPRESSION during processing
-- 4. Much more efficient than joining after unnesting
--
-- HOW IT WORKS:
-- - UNNEST(season_stats) converts array → one row per season
-- - ::season_stats casts to struct type
-- - (season_stats::season_stats).* expands all struct fields
-- ==================================================================================

WITH unnested AS (SELECT player_name,
                         UNNEST(season_stats)::season_stats AS season_stats
                  FROM players
                  WHERE current_season = 2001
                    AND player_name = 'Michael Jordan')

SELECT player_name,
       (season_stats::season_stats).* -- Expand all fields: season, gp, pts, reb, ast
FROM unnested;

-- ==================================================================================
-- TABLE EVOLUTION: Adding Calculated Dimensions
-- ==================================================================================
-- Drop and recreate the table to add new calculated dimensions
-- In production, you'd use ALTER TABLE or create a new version
-- ==================================================================================

DROP TABLE players;

-- ==================================================================================
-- ENUM TYPE: scoring_class
-- ==================================================================================
-- Define discrete categories for player performance based on points per game
-- ENUMs are efficient: stored as integers internally, displayed as text
-- Guarantees only valid values can be stored
-- ==================================================================================

CREATE TYPE scoring_class AS ENUM ('bad', 'average', 'good', 'star');

-- ==================================================================================
-- ENHANCED CUMULATIVE TABLE: players v2
-- ==================================================================================
-- Same structure as before, but now with two new calculated dimensions:
--
-- scoring_class: Current performance tier
-- - Calculated from latest season's points per game
-- - Helps segment players for analysis
-- - Changes over time as performance changes
--
-- years_since_last_season: Activity tracking
-- - 0 = played this season (active)
-- - 1+ = number of years since last game (inactive/retired)
-- - Helps identify retired players or career gaps
-- ==================================================================================

CREATE TABLE players
(
    player_name             TEXT,
    height                  TEXT,
    college                 TEXT,
    country                 TEXT,
    draft_year              TEXT,
    draft_round             TEXT,
    draft_number            TEXT,
    season_stats            season_stats[],
    scoring_class           scoring_class, -- NEW: Performance tier
    years_since_last_season INTEGER,       -- NEW: Activity tracker
    current_season          INTEGER,
    PRIMARY KEY (player_name, current_season)
);

-- ==================================================================================
-- ENHANCED INCREMENTAL INSERT: With Calculated Dimensions
-- ==================================================================================
-- Same "yesterday + today" pattern, but now calculates:
-- 1. scoring_class: Categorize player performance
-- 2. years_since_last_season: Track activity/inactivity
--
-- SCORING_CLASS LOGIC:
-- - > 20 pts/game = 'star'    (elite performers)
-- - > 15 pts/game = 'good'    (solid contributors)
-- - > 10 pts/game = 'average' (role players)
-- - ≤ 10 pts/game = 'bad'     (bench players)
--
-- YEARS_SINCE_LAST_SEASON LOGIC:
-- - 0 if player is active this season
-- - Increment by 1 if player is inactive (carries forward + 1)
-- - Helps identify: retirements, injuries, career gaps
-- ==================================================================================

INSERT INTO players
WITH yesterday AS (SELECT *
                   FROM players
                   WHERE current_season = 2000),
     today AS (SELECT *
               FROM player_seasons
               WHERE season = 2001)

SELECT COALESCE(t.player_name, y.player_name)   AS player_name,
       -- Slowly changing dimensions: take latest value
       COALESCE(t.height, y.height)             AS height,
       COALESCE(t.college, y.college)           AS college,
       COALESCE(t.country, y.country)           AS country,
       COALESCE(t.draft_year, y.draft_year)     AS draft_year,
       COALESCE(t.draft_round, y.draft_round)   AS draft_round,
       COALESCE(t.draft_number, y.draft_number) AS draft_number,
       -- Build temporal history array
       CASE
           WHEN y.season_stats IS NULL THEN ARRAY [ROW (t.season, t.gp, t.pts, t.reb, t.ast)::season_stats]
           WHEN t.season IS NOT NULL THEN y.season_stats || ARRAY [ROW (t.season, t.gp, t.pts, t.reb, t.ast)::season_stats]
           ELSE y.season_stats
           END                                  AS season_stats,
       -- CALCULATED DIMENSION: scoring_class
       -- If player is active (t.season IS NOT NULL), calculate from current pts
       -- If inactive, carry forward yesterday's scoring_class
       CASE
           WHEN t.season IS NOT NULL THEN
               (CASE
                    WHEN t.pts > 20 THEN 'star'
                    WHEN t.pts > 15 THEN 'good'
                    WHEN t.pts > 10 THEN 'average'
                    ELSE 'bad'
                   END)::scoring_class
           ELSE y.scoring_class
           END                                  AS scoring_class,
       -- CALCULATED DIMENSION: years_since_last_season
       -- Reset to 0 if player is active, otherwise increment
       CASE
           WHEN t.season IS NOT NULL THEN 0
           ELSE y.years_since_last_season + 1
           END                                  AS years_since_last_season,
       COALESCE(t.season, y.current_season + 1) AS current_season
FROM today t
         FULL OUTER JOIN yesterday y
                         ON t.player_name = y.player_name;

-- ==================================================================================
-- VERIFICATION: Check enhanced table output
-- ==================================================================================

-- Check cumulative updated table output with new fields
-- Notice: data is always sorted by player_name due to FULL OUTER JOIN
SELECT *
FROM players
WHERE current_season = 2001;

-- ==================================================================================
-- SPECIAL CASES: Michael Jordan's Career Evolution
-- ==================================================================================

-- Check Michael Jordan's 2001 season (comeback year)
-- - New season_stats entry for 2001
-- - scoring_class updated based on 2001 performance
-- - years_since_last_season reset to 0 (active again)
SELECT *
FROM players
WHERE current_season = 2001
  AND player_name = 'Michael Jordan';

-- Check Michael Jordan's 2000 season (retired)
-- - No 2000 season_stats entry (retired)
-- - years_since_last_season = 3 (1998, 1999, 2000)
-- - scoring_class from last active season (1997)
SELECT *
FROM players
WHERE current_season = 2000
  AND player_name = 'Michael Jordan';

-- ==================================================================================
-- ARRAY INDEXING: Accessing First and Last Seasons
-- ==================================================================================
-- PostgreSQL arrays are 1-indexed (first element is [1], not [0])
-- CARDINALITY() returns the number of elements in an array
--
-- TECHNIQUES SHOWN:
-- - season_stats[1]: First season (rookie year)
-- - season_stats[CARDINALITY(season_stats)]: Last season (most recent)
-- - ::season_stats cast: Convert array element to struct type
-- - .pts access: Extract specific field from struct
-- ==================================================================================

-- Compare first season vs latest season (entire struct)
SELECT player_name,
       season_stats[1]                         AS first_season,
       season_stats[CARDINALITY(season_stats)] AS latest_season
FROM players
WHERE current_season = 2001;

-- Compare first season vs latest season (points only)
SELECT player_name,
       (season_stats[1]::season_stats).pts                         AS first_season_pts,
       (season_stats[CARDINALITY(season_stats)]::season_stats).pts AS latest_season_pts
FROM players
WHERE current_season = 2001;

-- ==================================================================================
-- CAREER PROGRESSION ANALYSIS: Calculate Improvement Ratio
-- ==================================================================================
-- This calculates how much a player's scoring has improved from rookie to current
-- Ratio > 1.0 means improvement, < 1.0 means decline
--
-- WHY AVOID DIVISION BY ZERO?
-- Some players might have 0 pts in their first season (injury, didn't play)
-- CASE statement ensures we don't divide by zero
-- ==================================================================================

-- Calculate percent improvement from first season to latest season
SELECT player_name,
       (season_stats[CARDINALITY(season_stats)]::season_stats).pts /
       CASE
           WHEN (season_stats[1]::season_stats).pts = 0 THEN 1
           ELSE (season_stats[1]::season_stats).pts
           END AS improvement_ratio
FROM players
WHERE current_season = 2001;

-- ==================================================================================
-- PERFORMANCE BENEFIT: No GROUP BY Needed!
-- ==================================================================================
-- This query demonstrates a key advantage of cumulative tables:
-- All calculations happen per-row, NO aggregation needed
--
-- COMPARISON TO TRADITIONAL APPROACH:
-- - Traditional: JOIN player_seasons multiple times, GROUP BY, aggregate
-- - Cumulative: Direct array access, no joins, no grouping
--
-- SLOWEST PART: ORDER BY DESC (sorting the result)
-- Everything else is just reading from one row per player
-- ==================================================================================

-- Show improvement ratio, sorted by highest improvement
-- Notice: NO GROUP BY clause needed!
SELECT player_name,
       (season_stats[CARDINALITY(season_stats)]::season_stats).pts /
       CASE
           WHEN (season_stats[1]::season_stats).pts = 0 THEN 1
           ELSE (season_stats[1]::season_stats).pts
           END AS improvement_ratio
FROM players
WHERE current_season = 2001
ORDER BY 2 DESC;

-- ==================================================================================
-- COMBINED FILTERING: Dimension + Calculated Metric
-- ==================================================================================
-- Filter to only 'star' players and show their career progression
-- This demonstrates easy filtering on both:
-- - Pre-calculated dimensions (scoring_class)
-- - Array-based temporal data (season stats)
-- ==================================================================================

-- Show improvement ratio for star players only
SELECT player_name,
       (season_stats[CARDINALITY(season_stats)]::season_stats).pts /
       CASE
           WHEN (season_stats[1]::season_stats).pts = 0 THEN 1
           ELSE (season_stats[1]::season_stats).pts
           END AS improvement_ratio
FROM players
WHERE current_season = 2001
  AND scoring_class = 'star';
