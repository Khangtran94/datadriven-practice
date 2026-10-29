CREATE TABLE dim_user (
    user_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    signup_at DATE,
    PRIMARY KEY (user_id)
);

CREATE TABLE fact_order (
    order_id INT,
    order_date DATE,
    user_id INT,
    order_time TIMESTAMP,
    delivery_time TIMESTAMP,
    amount DECIMAL,
    status_completed BOOLEAN,
    PRIMARY KEY (order_id)
);

CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE user_stat (
    user_stat_id INT,
    tracking_date DATE,
    user_id INT,
    total_revenue INT,
    total_order INT,
    customer_lifetime_value INT,
    PRIMARY KEY (user_stat_id)
);

CREATE TABLE overall_stat (
    stat_id INT,
    date_sk DATE,
    DAU INT,
    order_count INT,
    complete_count INT,
    order_completion_rate DECIMAL,
    average_delivery_time DECIMAL,
    PRIMARY KEY (stat_id)
);

ALTER TABLE fact_order
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);

ALTER TABLE fact_order
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);

ALTER TABLE overall_stat
    ADD FOREIGN KEY (date_sk) REFERENCES dim_date (date_sk);

ALTER TABLE user_stat
    ADD FOREIGN KEY (tracking_date) REFERENCES dim_date (date_sk);

ALTER TABLE user_stat
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);
