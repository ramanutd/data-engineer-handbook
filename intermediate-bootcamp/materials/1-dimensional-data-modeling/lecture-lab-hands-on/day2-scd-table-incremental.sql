-- ==================================================================================
-- CUSTOM TYPE: players_scd_type
-- ==================================================================================
-- Create a struct type to hold SCD record attributes
-- This is used in the changed_records CTE to create an array of both:
-- 1. The closing record (old values with original start_season/end_season)
-- 2. The opening record (new values starting in current season)
--
-- WHY USE A STRUCT?
-- - Allows UNNEST to create multiple rows from one player
-- - Type-safe: ensures all fields are present
-- - Cleaner than multiple UNION statements
-- ==================================================================================

CREATE TYPE players_scd_type AS
(
    scoring_class scoring_class,
    is_active     BOOLEAN,
    start_season  INTEGER,
    end_season    INTEGER
);

-- ==================================================================================
-- INCREMENTAL SCD TYPE 2: Processing One Season at a Time
-- ==================================================================================
-- This query implements an INCREMENTAL approach to building SCD Type 2
-- Instead of processing all history (like backfill), it processes only:
-- - Yesterday's SCD state (season 2021)
-- - Today's new data (season 2022)
--
-- THE ALGORITHM (5 CATEGORIES):
-- 1. historical_scd: Keep all historical records that are already closed
-- 2. unchanged_records: Players whose attributes didn't change (extend end_season)
-- 3. changed_records: Players whose attributes changed (close old, open new)
-- 4. new_records: Brand new players we've never seen before
--
-- ADVANTAGES OVER BACKFILL:
-- ✅ EFFICIENT: Only processes 2 seasons of data (not entire history)
-- ✅ SCALABLE: Works with billions of records (less memory pressure)
-- ✅ INCREMENTAL: Can run daily/seasonally without reprocessing everything
--
-- DISADVANTAGES:
-- ⚠️ SEQUENTIAL: Depends on yesterday's data (harder to backfill if data is lost)
-- ⚠️ COMPLEXITY: More edge cases to handle
-- ⚠️ DEPENDENCIES: Must run in order (can't skip seasons)
-- ==================================================================================

WITH last_season_scd AS (
    -- Get only the "active" SCD records from last season
    -- These are records where end_season = 2021 (still open/current as of last season)
    -- We need to decide: extend them, close them, or keep them as-is
    SELECT *
    FROM players_scd
    WHERE current_season = 2021
      AND end_season = 2021 -- Only records that were "current" last season
),

     historical_scd AS (
         -- Get all the "closed" historical records from last season
         -- These are records where end_season < 2021 (already in the past)
         -- We just carry these forward unchanged - they're historical facts
         SELECT player_name,
                scoring_class,
                is_active,
                start_season,
                end_season
         FROM players_scd
         WHERE current_season = 2021
           AND end_season < 2021 -- Only records that were already closed
     ),

     this_season_data AS (
         -- Get the current season's data (2022)
         -- This represents the "truth" for season 2022
         SELECT *
         FROM players
         WHERE current_season = 2022),

     unchanged_records AS (
         -- CASE 1: Players whose attributes DIDN'T change
         -- - Player exists in both seasons
         -- - scoring_class is the same
         -- - is_active is the same
         -- ACTION: Extend the end_season from 2021 → 2022
         --
         -- EXAMPLE: LeBron was 'star'/active in 2021, still 'star'/active in 2022
         -- Before: {LeBron, star, true, 2015, 2021}
         -- After:  {LeBron, star, true, 2015, 2022}  ← end_season extended
         SELECT ts.player_name,
                ts.scoring_class,
                ts.is_active,
                ls.start_season,                -- Keep original start_season
                ts.current_season AS end_season -- Extend to 2022
         FROM this_season_data ts
                  JOIN last_season_scd ls
                       ON ts.player_name = ls.player_name
         WHERE ts.scoring_class = ls.scoring_class -- No change in scoring
           AND ts.is_active = ls.is_active -- No change in activity
     ),

     changed_records AS (
         -- CASE 2: Players whose attributes CHANGED
         -- - Player exists in both seasons
         -- - scoring_class changed OR is_active changed
         -- ACTION: Create 2 records using UNNEST
         --   1. Close the old record (keep original start_season, end_season stays 2021)
         --   2. Open a new record (new values, start_season = 2022, end_season = 2022)
         --
         -- EXAMPLE: Kobe was 'star'/active in 2021, became 'good'/active in 2022
         -- Before: {Kobe, star, true, 2010, 2021}
         -- After:  {Kobe, star, true, 2010, 2021}  ← old record (closed)
         --         {Kobe, good, true, 2022, 2022}  ← new record (opened)
         --
         -- UNNEST TECHNIQUE:
         -- We create an array of 2 structs and UNNEST it to generate 2 rows
         SELECT ts.player_name,
                UNNEST(ARRAY [
                    -- Record 1: The old record (closing it)
                    ROW (ls.scoring_class, ls.is_active, ls.start_season, ls.end_season)::players_scd_type,
                    -- Record 2: The new record (opening it)
                    ROW (ts.scoring_class, ts.is_active, ts.current_season, ts.current_season)::players_scd_type
                    ]) AS records
         FROM this_season_data ts
                  LEFT JOIN last_season_scd ls
                            ON ts.player_name = ls.player_name
         WHERE ts.scoring_class <> ls.scoring_class -- Change detected in scoring
            OR ts.is_active <> ls.is_active -- Change detected in activity
     ),

     unnested_changed_records AS (
         -- Expand the UNNEST results from changed_records
         -- Extract all fields from the players_scd_type struct
         SELECT player_name,
                (records::players_scd_type).scoring_class,
                (records::players_scd_type).is_active,
                (records::players_scd_type).start_season,
                (records::players_scd_type).end_season
         FROM changed_records),

     new_records AS (
         -- CASE 3: Brand new players
         -- - Player exists in this_season_data (2022)
         -- - Player does NOT exist in last_season_scd
         -- ACTION: Create a new SCD record starting in 2022
         --
         -- EXAMPLE: Rookie player drafted in 2022
         -- Result: {Rookie, good, true, 2022, 2022}  ← first ever record
         --
         -- LEFT JOIN with WHERE ls.player_name IS NULL finds new players
         SELECT ts.player_name,
                ts.scoring_class,
                ts.is_active,
                ts.current_season AS start_season, -- First appearance
                ts.current_season AS end_season    -- Currently active
         FROM this_season_data ts
                  LEFT JOIN last_season_scd ls
                            ON ts.player_name = ls.player_name
         WHERE ls.player_name IS NULL -- Player didn't exist in last season's active records
     )

-- ==================================================================================
-- FINAL UNION: Combine All Categories
-- ==================================================================================
-- UNION ALL combines all 4 categories:
-- 1. historical_scd: Old closed records (unchanged)
-- 2. unchanged_records: Extended records (same attributes)
-- 3. unnested_changed_records: Closed old + opened new records
-- 4. new_records: Brand new player records
--
-- Note: We don't add current_season = 2022 here - would be added in production INSERT
-- ==================================================================================

SELECT *
FROM historical_scd

UNION ALL

SELECT *
FROM unchanged_records

UNION ALL

SELECT *
FROM unnested_changed_records

UNION ALL

SELECT *
FROM new_records

ORDER BY player_name, start_season;

-- ==================================================================================
-- EDGE CASES & CONSIDERATIONS
-- ==================================================================================
/*
⚠️ IMPORTANT EDGE CASES TO HANDLE:

1. NEW PLAYERS (Rookies/Trades):
   - Handled by new_records CTE
   - LEFT JOIN with WHERE IS NULL finds players not in last season

2. RETIRED PLAYERS (No longer active):
   - If player was in 2021 but NOT in 2022
   - Currently NOT explicitly handled!
   - Solution: Add another CTE for "disappeared players" to close their records

3. PLAYERS WHO CHANGE MULTIPLE TIMES IN ONE SEASON:
   - If player_seasons had multiple rows per season, this wouldn't work
   - Assumes one row per player per season
   - Solution: Pre-aggregate or use last known state within season

4. PLAYERS RETURNING AFTER RETIREMENT:
   - If player was in 2020, not in 2021, back in 2022
   - Would appear as "new_record" in 2022
   - Historical link to pre-retirement period is maintained via historical_scd
   - Solution: Consider is_active flag to track retirement vs true new players

5. NULL VALUES IN TRACKED DIMENSIONS:
   - Current comparison uses <> which treats NULL <> NULL as NULL (false)
   - If scoring_class or is_active can be NULL, comparisons fail
   - Solution: Use IS DISTINCT FROM instead of <>
     Example: WHERE ts.scoring_class IS DISTINCT FROM ls.scoring_class

6. DATA QUALITY ISSUES:
   - Missing data for specific seasons
   - Duplicate records in source
   - Solution: Add data validation and deduplication before SCD processing

7. BACKFILL CHALLENGES:
   - Sequential dependency: can't skip seasons
   - If season 2020 data is missing, can't process 2021 correctly
   - Solution: Use backfill approach first, then switch to incremental

COMPARISON TO BACKFILL APPROACH:
- Backfill: Easier to understand, harder to scale, easier to backfill
- Incremental: More complex, scales better, harder to recover from gaps

BEST PRACTICE:
- Use backfill for initial historical load
- Use incremental for ongoing daily/seasonal updates
- Keep backfill logic available for disaster recovery
*/