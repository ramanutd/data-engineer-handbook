-- cumulative query to generate device_activity_datelist from events
-- This implements an incremental cumulative table pattern combining yesterday's data with today's new data

DO
$$
    DECLARE
        y_date         DATE;
        t_date         DATE;
        min_event_date DATE;
        max_event_date DATE;
    BEGIN
        -- Get the min and max dates from events table
        SELECT MIN(DATE(CAST(event_time AS TIMESTAMP))),
               MAX(DATE(CAST(event_time AS TIMESTAMP)))
        INTO min_event_date, max_event_date
        FROM events;

        -- Loop through each date from min to max
        FOR y_date IN SELECT GENERATE_SERIES(min_event_date - INTERVAL '1 day', max_event_date - INTERVAL '1 day',
                                             '1 day'::INTERVAL)::DATE
            LOOP
                t_date := (y_date + INTERVAL '1 day')::DATE;

                INSERT INTO user_devices_cumulated
                WITH yesterday AS (SELECT *
                                   FROM user_devices_cumulated
                                   WHERE date = y_date),
                     today AS (SELECT e.user_id,
                                      DATE(CAST(e.event_time AS TIMESTAMP)) AS date_active,
                                      d.browser_type                        AS browser_type
                               FROM events e
                                        LEFT JOIN devices d
                                                  ON e.device_id = d.device_id
                               WHERE DATE(CAST(e.event_time AS TIMESTAMP)) = t_date
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

            END LOOP;
    END
$$;
