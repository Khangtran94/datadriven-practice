CREATE TABLE dim_user (
    user_sk INT,
    user_id INT,
    name CHAR,
    subscription_tier CHAR,
    country CHAR,
    from_date DATE,
    to_date DATE,
    is_active BOOLEAN,
    PRIMARY KEY (user_sk)
);

CREATE TABLE dim_date (
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (full_date)
);

CREATE TABLE fact_event (
    event_id INT,
    event_date DATE,
    user_sk INT,
    revenue DECIMAL,
    PRIMARY KEY (event_id)
);

ALTER TABLE dim_user
    ADD FOREIGN KEY (from_date) REFERENCES dim_date (full_date);

ALTER TABLE dim_user
    ADD FOREIGN KEY (to_date) REFERENCES dim_date (full_date);

ALTER TABLE fact_event
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (full_date);

ALTER TABLE fact_event
    ADD FOREIGN KEY (user_sk) REFERENCES dim_user (user_sk);
