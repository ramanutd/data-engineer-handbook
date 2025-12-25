-- DDL for user_devices_cumulated table

CREATE TABLE user_devices_cumulated
(
    user_id                  NUMERIC,
    device_activity_datelist DATE[],
    browser_type             TEXT,
    date                     DATE,
    PRIMARY KEY (user_id, browser_type, date)
);