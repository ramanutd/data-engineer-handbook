-- Query to deduplicate game_details so there's no duplicates
-- Uses ROW_NUMBER() window function to identify and remove duplicate records based on game_id, team_id, and player_id

WITH deduped_game_details AS (SELECT *,
                                     ROW_NUMBER()
                                     OVER (PARTITION BY game_id, team_id, player_id) AS row_num
                              FROM game_details)
SELECT *
FROM deduped_game_details
WHERE row_num = 1;
