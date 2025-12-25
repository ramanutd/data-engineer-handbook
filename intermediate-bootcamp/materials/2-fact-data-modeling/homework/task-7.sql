-- monthly reduced fact table DDL host_activity_reduced

CREATE TABLE host_activity_reduced
(
    host                   TEXT,
    month_start            DATE,
    hit_metric             TEXT,
    hit_array              INTEGER[],
    unique_visitors_metric TEXT,
    unique_visitors_array  NUMERIC[],
    PRIMARY KEY (host, month_start, hit_metric, unique_visitors_metric)
);