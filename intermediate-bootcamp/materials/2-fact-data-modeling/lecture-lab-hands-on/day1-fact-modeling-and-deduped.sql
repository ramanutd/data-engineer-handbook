-- ==================================================================================
-- DATA QUALITY CHECK: Identify Duplicates
-- ==================================================================================
-- This query checks for duplicate records in the game_details table.
-- A unique record should be identified by: game_id + team_id + player_id
-- (one player can only play for one team in one game)
--
-- If COUNT(1) > 1, it means the same player appears multiple times for the same
-- team in the same game, which indicates a data quality issue that needs fixing.
-- ==================================================================================

SELECT game_id,
       team_id,
       player_id,
       COUNT(1) AS duplicate_count
FROM game_details
GROUP BY game_id, team_id, player_id
HAVING COUNT(1) > 1;

-- ==================================================================================
-- DEDUPLICATION STRATEGY: Keep Earliest Record
-- ==================================================================================
-- This query removes duplicates by keeping only the record with the earliest
-- game_date_est (from the games table).
--
-- TECHNIQUE: ROW_NUMBER() Window Function
-- - PARTITION BY: Creates separate groups for each unique combination
--   (game_id, team_id, player_id)
-- - ORDER BY: Within each group, ranks records by game_date_est (earliest first)
-- - WHERE row_num = 1: Keeps only the first (earliest) record from each group
--
-- WHY JOIN WITH games TABLE?
-- The game_details table doesn't have game_date_est, so we need to join with
-- the games table to access this date for proper ordering.
--
-- ADDITIONAL TRANSFORMATIONS:
-- - Converting boolean flags from comments (DNP, DND, NWT)
-- - Parsing minutes from "MM:SS" format to decimal
-- - Creating dimension flags (e.g., dim_is_playing_at_home)
-- ==================================================================================

WITH deduped AS (SELECT g.game_date_est,
                        g.season,
                        g.home_team_id,
                        gd.*,
                        -- Assign row numbers within each partition, ordered by earliest date
                        ROW_NUMBER()
                        OVER (PARTITION BY gd.game_id, gd.team_id, gd.player_id ORDER BY g.game_date_est) AS row_num
                 FROM game_details gd
                          JOIN games g ON gd.game_id = g.game_id)
SELECT game_date_est,
       season,
       team_id,
       player_id,
       player_name,
       start_position,
       -- DIMENSION: Check if player's team matches home team
       team_id = home_team_id                                                             AS dim_is_playing_at_home,
       -- DIMENSIONS: Parse status flags from comment field
       COALESCE(POSITION('DNP' IN comment), 0) > 0                                        AS dim_did_not_play,
       COALESCE(POSITION('DND' IN comment), 0) > 0                                        AS dim_did_not_dress,
       COALESCE(POSITION('NWT' IN comment), 0) > 0                                        AS dim_not_with_team,
       -- MEASURE: Convert minutes from "MM:SS" format to decimal (e.g., "25:30" → 25.5)
       CAST(SPLIT_PART(min, ':', 1) AS REAL) + CAST(SPLIT_PART(min, ':', 2) AS REAL) / 60 AS minutes,
       fgm,
       fga,
       fg3m,
       fg3a,
       ftm,
       fta,
       oreb,
       dreb,
       reb,
       ast,
       stl,
       blk,
       "TO"                                                                               AS turnovers,
       pf,
       pts,
       plus_minus
FROM deduped
WHERE row_num = 1;
-- Keep only the first (earliest) record from each group

-- ==================================================================================
-- FACT TABLE DESIGN: fct_game_details
-- ==================================================================================
-- This is a proper fact table following dimensional modeling best practices.
--
-- NAMING CONVENTIONS:
-- - dim_* : Dimensions (attributes that describe the facts)
-- - m_*   : Measures (numeric values that can be aggregated)
--
-- WHY SEPARATE DIMENSIONS FROM MEASURES?
-- - Makes it clear what can be aggregated (measures) vs what describes the data (dimensions)
-- - Follows Kimball dimensional modeling methodology
-- - Easier for analysts to understand and query
--
-- PRIMARY KEY: (dim_game_date, dim_team_id, dim_player_id)
-- - This ensures each player can only have one record per game per team
-- - Prevents duplicate data at insert time
--
-- DESIGN CHOICES:
-- - Store team_id but NOT all team details (use JOIN with teams dimension table)
-- - Pre-calculate boolean dimensions (is_playing_at_home, did_not_play, etc.)
-- - Convert minutes to decimal format for easier aggregation
-- - Descriptive column names with proper prefixes
-- ==================================================================================

CREATE TABLE fct_game_details
(
    -- DIMENSIONS: Descriptive attributes
    dim_game_date                       DATE,
    dim_season                          INTEGER,
    dim_team_id                         INTEGER, -- FK to teams dimension
    dim_player_id                       INTEGER, -- FK to players dimension
    dim_player_name                     VARCHAR,
    dim_start_position                  TEXT,
    dim_is_playing_at_home              BOOLEAN,
    dim_did_not_play                    BOOLEAN,
    dim_did_not_dress                   BOOLEAN,
    dim_not_with_team                   BOOLEAN,

    -- MEASURES: Numeric values that can be aggregated
    m_minutes                           REAL,
    m_field_goals_made                  INTEGER,
    m_field_goals_attempted             INTEGER,
    m_three_point_field_goals_made      INTEGER,
    m_three_point_field_goals_attempted INTEGER,
    m_free_throws_made                  INTEGER,
    m_free_throws_attempted             INTEGER,
    m_offensive_rebounds                INTEGER,
    m_defensive_rebounds                INTEGER,
    m_total_rebounds                    INTEGER,
    m_assists                           INTEGER,
    m_steals                            INTEGER,
    m_blocks                            INTEGER,
    m_turnovers                         INTEGER,
    m_personal_fouls                    INTEGER,
    m_points                            INTEGER,
    m_plus_minus                        INTEGER,

    PRIMARY KEY (dim_game_date, dim_team_id, dim_player_id)
);

-- ==================================================================================
-- POPULATE FACT TABLE: Insert deduplicated and transformed data
-- ==================================================================================
-- This INSERT statement performs three key operations:
-- 1. DEDUPLICATION: Using ROW_NUMBER() to keep only the earliest record per player/game
-- 2. TRANSFORMATION: Convert raw data to proper formats and types
-- 3. ENRICHMENT: Add calculated dimensions (home/away, status flags)
--
-- TRANSFORMATION DETAILS:
-- - Boolean extraction from comment field: POSITION('DNP' IN comment) finds the substring
-- - Minutes parsing: SPLIT_PART breaks "MM:SS" into parts, then converts to decimal
-- - Home/away flag: Compare team_id with home_team_id to determine location
--
-- This is a one-time backfill operation. For production, you'd run this incrementally.
-- ==================================================================================

INSERT INTO fct_game_details
WITH deduped AS (SELECT g.game_date_est,
                        g.season,
                        g.home_team_id,
                        gd.*,
                        -- Window function to rank duplicates by earliest game date
                        ROW_NUMBER()
                        OVER (PARTITION BY gd.game_id, gd.team_id, gd.player_id ORDER BY g.game_date_est) AS row_num
                 FROM game_details gd
                          JOIN games g ON gd.game_id = g.game_id)

SELECT game_date_est                                                                      AS dim_game_date,
       season                                                                             AS dim_season,
       team_id                                                                            AS dim_team_id,
       player_id                                                                          AS dim_player_id,
       player_name                                                                        AS dim_player_name,
       start_position                                                                     AS dim_start_position,
       -- CALCULATED DIMENSION: Check if playing at home
       team_id = home_team_id                                                             AS dim_is_playing_at_home,
       -- PARSE BOOLEAN FLAGS from comment string
       -- POSITION returns the index where substring is found (0 if not found)
       COALESCE(POSITION('DNP' IN comment), 0) > 0                                        AS dim_did_not_play,
       COALESCE(POSITION('DND' IN comment), 0) > 0                                        AS dim_did_not_dress,
       COALESCE(POSITION('NWT' IN comment), 0) > 0                                        AS dim_not_with_team,
       -- CONVERT MINUTES: "25:30" → 25 + (30/60) = 25.5 minutes
       CAST(SPLIT_PART(min, ':', 1) AS REAL) + CAST(SPLIT_PART(min, ':', 2) AS REAL) / 60 AS m_minutes,
       fgm                                                                                AS m_field_goals_made,
       fga                                                                                AS m_field_goals_attempted,
       fg3m                                                                               AS m_three_point_field_goals_made,
       fg3a                                                                               AS m_three_point_field_goals_attempted,
       ftm                                                                                AS m_free_throws_made,
       fta                                                                                AS m_free_throws_attempted,
       oreb                                                                               AS m_offensive_rebounds,
       dreb                                                                               AS m_defensive_rebounds,
       reb                                                                                AS m_total_rebounds,
       ast                                                                                AS m_assists,
       stl                                                                                AS m_steals,
       blk                                                                                AS m_blocks,
       "TO"                                                                               AS m_turnovers,
       pf                                                                                 AS m_personal_fouls,
       pts                                                                                AS m_points,
       plus_minus                                                                         AS m_plus_minus
FROM deduped
WHERE row_num = 1;
-- Only keep the first (earliest) record from each duplicate group


-- ==================================================================================
-- STAR SCHEMA PATTERN: Joining Fact with Dimension Tables
-- ==================================================================================
-- This demonstrates the power of dimensional modeling:
--
-- BENEFITS:
-- 1. STORAGE EFFICIENCY: We only store team_id in the fact table, not all team details
--    - Fact table: millions of rows with just an integer ID
--    - Dimension table: small (30-40 teams) with full details
--
-- 2. CONSISTENCY: All team information comes from one authoritative source
--    - If team name changes, update dimension table once
--    - All queries automatically get the updated name
--
-- 3. PERFORMANCE: This JOIN is cheap because:
--    - Teams dimension is small (easily fits in memory)
--    - Database can cache the dimension table
--    - Join on integer keys is very fast
--
-- 4. FLEXIBILITY: Easy to add new team attributes without touching fact table
--
-- This is the "star schema" - fact table in center, dimension tables as points
-- ==================================================================================

SELECT t.*, fgd.*
FROM fct_game_details fgd
         JOIN teams t
              ON fgd.dim_team_id = t.team_id;


-- ==================================================================================
-- SAMPLE ANALYTICS QUERY: Demonstrating Benefits of Proper Fact Table Design
-- ==================================================================================
-- This query calculates multiple metrics per player based on home/away games:
-- - Number of games played
-- - Total points scored
-- - Games where player was "not with team"
-- - Percentage of games where player bailed
--
-- WHY THIS IS EASY WITH OUR FACT TABLE DESIGN:
-- 1. Pre-calculated dimensions: dim_is_playing_at_home, dim_not_with_team are ready to use
-- 2. Clean data: Deduplication already done, no need to worry about duplicates
-- 3. Proper data types: Boolean flags make filtering intuitive
-- 4. Clear naming: dim_* and m_* prefixes make it obvious what to GROUP BY vs SUM
--
-- QUERY BREAKDOWN:
-- - GROUP BY dim_player_name, dim_is_playing_at_home: Separate home vs away stats
-- - COUNT(1): Total games for each player/location combination
-- - SUM(m_points): Total points (measures are aggregatable)
-- - COUNT(CASE WHEN...): Conditional count for specific dimension
-- - CAST to REAL for percentage calculation to avoid integer division
-- - ORDER BY 6 DESC: Sort by bail percentage (column 6)
--
-- COMPARE TO RAW DATA APPROACH:
-- If using raw game_details table, you'd need to:
-- 1. Deduplicate within the query (slower, more complex)
-- 2. Parse comment field every time (inefficient)
-- 3. Join to games for home team every time (extra JOIN overhead)
-- 4. Convert minutes format every time (redundant processing)
-- ==================================================================================

SELECT dim_player_name,
       dim_is_playing_at_home,
       COUNT(1)                                                               AS num_games,
       SUM(m_points)                                                          AS total_points,
       COUNT(CASE WHEN dim_not_with_team THEN 1 END)                          AS bailed_num,
       CAST(COUNT(CASE WHEN dim_not_with_team THEN 1 END) AS REAL) / COUNT(1) AS bailed_pct
FROM fct_game_details
GROUP BY dim_player_name, dim_is_playing_at_home
ORDER BY 6 DESC;

