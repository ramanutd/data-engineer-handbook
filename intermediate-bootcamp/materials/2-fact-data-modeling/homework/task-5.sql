-- TASK 5: DDL for hosts_cumulated table
--
-- This table tracks cumulative activity per host (website domain) over time.
-- Similar to user_devices_cumulated but aggregated at the host level instead of user level.
--
-- Structure:
--   - host: Website domain/hostname (e.g., 'www.zachwilson.tech', 'www.eczachly.com')
--   - host_activity_datelist: Array of all dates when this host had any user activity
--   - date: The snapshot date for this cumulative record
--
-- Use Case: Track which days each host experienced traffic/activity
-- Primary Key: Composite key on (host, date) ensures one snapshot per host per day

CREATE TABLE hosts_cumulated
(
    host                   TEXT,
    host_activity_datelist DATE[],
    date                   DATE,
    PRIMARY KEY (host, date)
);