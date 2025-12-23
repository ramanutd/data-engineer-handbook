-- Identify duplicates in game_details table based on game_id, team_id, and player_id
SELECT game_id,
       team_id,
       player_id,
       COUNT(1)
FROM game_details
GROUP BY game_id, team_id, player_id
HAVING COUNT(1) > 1;

-- Remove duplicates by keeping the record with the earliest game_date_est from the games table
WITH deduped AS (SELECT g.game_date_est,
                        g.season,
                        g.home_team_id,
                        gd.*,
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
       team_id = home_team_id                                                             AS dim_is_playing_at_home,
       COALESCE(POSITION('DNP' IN comment), 0) > 0                                        AS dim_did_not_play,
       COALESCE(POSITION('DND' IN comment), 0) > 0                                        AS dim_did_not_dress,
       COALESCE(POSITION('NWT' IN comment), 0) > 0                                        AS dim_not_with_team,
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

-- Create the fact table fct_game_details
-- follows proper naming conventions for dimensions (dim_) and measures (m_)
CREATE TABLE fct_game_details
(
    dim_game_date                       DATE,
    dim_season                          INTEGER,
    dim_team_id                         INTEGER,
    dim_player_id                       INTEGER,
    dim_player_name                     VARCHAR,
    dim_start_position                  TEXT,
    dim_is_playing_at_home              BOOLEAN,
    dim_did_not_play                    BOOLEAN,
    dim_did_not_dress                   BOOLEAN,
    dim_not_with_team                   BOOLEAN,
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

-- Populate the fact table fct_game_details from deduplicated game_details data
INSERT INTO fct_game_details
WITH deduped AS (SELECT g.game_date_est,
                        g.season,
                        g.home_team_id,
                        gd.*,
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
       team_id = home_team_id                                                             AS dim_is_playing_at_home,
       COALESCE(POSITION('DNP' IN comment), 0) > 0                                        AS dim_did_not_play,
       COALESCE(POSITION('DND' IN comment), 0) > 0                                        AS dim_did_not_dress,
       COALESCE(POSITION('NWT' IN comment), 0) > 0                                        AS dim_not_with_team,
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


-- easy to get team details along with fact data for analysis queries by joining fct_game_details with teams dimension table
-- instead of having all team details in the fact table like in game_details
-- and this join is not expensive as teams is a small dimension table
SELECT t.*, fgd.*
FROM fct_game_details fgd
         JOIN teams t
              ON fgd.dim_team_id = t.team_id;


-- Sample analysis query: Calculate the number and percentage of games where each player was not with the team
-- number of games and total points scored by each player when playing at home vs away
-- its easy to run such analysis queries on the fact table
-- as it is already cleaned and modeled properly
SELECT dim_player_name,
       dim_is_playing_at_home,
       COUNT(1)                                                               AS num_games,
       SUM(m_points)                                                          AS total_points,
       COUNT(CASE WHEN dim_not_with_team THEN 1 END)                          AS bailed_num,
       CAST(COUNT(CASE WHEN dim_not_with_team THEN 1 END) AS REAL) / COUNT(1) AS bailed_pct
FROM fct_game_details
GROUP BY dim_player_name, dim_is_playing_at_home
ORDER BY 6 DESC;

