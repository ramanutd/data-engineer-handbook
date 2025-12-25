-- cumulative query to generate device_activity_datelist from events
-- This implements an incremental cumulative table pattern combining yesterday's data with today's new data

INSERT INTO user_devices_cumulated
WITH yesterday AS (SELECT *
                   FROM user_devices_cumulated
                   WHERE date = DATE('2023-01-30')),

     today AS (SELECT e.user_id,
                      DATE(CAST(e.event_time AS TIMESTAMP)) AS date_active,
                      d.browser_type                        AS browser_type
               FROM events e
                        LEFT JOIN devices d
                                  ON e.device_id = d.device_id
               WHERE DATE(CAST(e.event_time AS TIMESTAMP)) = DATE('2023-01-31')
                 AND e.user_id IS NOT NULL
                 AND d.browser_type IS NOT NULL
               GROUP BY e.user_id,
                        DATE(CAST(e.event_time AS TIMESTAMP)),
                        d.browser_type)

SELECT COALESCE(t.user_id, y.user_id)                     AS user_id,
       CASE
           WHEN y.device_activity_datelist IS NULL THEN ARRAY [t.date_active]
           WHEN t.date_active IS NULL THEN y.device_activity_datelist
           ELSE ARRAY [t.date_active] || y.device_activity_datelist
           END                                            AS device_activity_datelist,
       COALESCE(t.browser_type, y.browser_type)           AS browser_type,
       COALESCE(t.date_active, y.date + INTERVAL '1 day') AS date
FROM today t
         FULL OUTER JOIN yesterday y
                         ON t.user_id = y.user_id
                             AND t.browser_type = y.browser_type;
