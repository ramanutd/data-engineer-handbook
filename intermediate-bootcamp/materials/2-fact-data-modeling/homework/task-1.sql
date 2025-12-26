-- TASK 1: Deduplication query for game_details table
--
-- This query removes duplicate records from game_details by:
-- 1. Using ROW_NUMBER() window function partitioned by game_id, team_id, and player_id
-- 2. Assigning a sequential number to each duplicate row within the partition
-- 3. Filtering to keep only the first occurrence (row_num = 1) of each unique combination
-- This ensures each game-team-player combination appears only once in the result set

WITH deduped_game_details AS (SELECT *,
                                     ROW_NUMBER()
                                     OVER (PARTITION BY game_id, team_id, player_id) AS row_num
                              FROM game_details)
SELECT *
FROM deduped_game_details
WHERE row_num = 1;
