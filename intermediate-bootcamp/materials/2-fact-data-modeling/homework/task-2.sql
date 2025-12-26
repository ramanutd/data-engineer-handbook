-- TASK 2: DDL for user_devices_cumulated table
--
-- This table implements a cumulative snapshot pattern to track user device activity over time.
-- Structure:
--   - user_id: Unique identifier for each user
--   - device_activity_datelist: Array of dates when user was active (cumulative history)
--   - browser_type: Type of browser used (Chrome, Firefox, Safari, etc.)
--   - date: The snapshot date for this cumulative record
--
-- Design Decision: Using browser_type as a separate column with multiple rows per user
-- (Alternative would be MAP<STRING, ARRAY[DATE]> but PostgreSQL arrays are more efficient)
-- Primary Key: Composite key ensures one record per user-browser-date combination

CREATE TABLE user_devices_cumulated
(
    user_id                  NUMERIC,
    device_activity_datelist DATE[],
    browser_type             TEXT,
    date                     DATE,
    PRIMARY KEY (user_id, browser_type, date)
);