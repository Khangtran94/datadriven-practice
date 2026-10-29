CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_user (
    user_id INT,
    signup_date DATE,
    channel_id INT,
    username INT,
    phone INT,
    email CHAR,
    PRIMARY KEY (user_id)
);

CREATE TABLE summary_user (
    date_sk DATE,
    user_id INT,
    number_of_session INT,
    number_of_video_watched INT,
    watch_time DECIMAL,
    PRIMARY KEY (date_sk, user_id)
);

CREATE TABLE dim_channel (
    channel_id INT,
    name CHAR,
    type CHAR,
    PRIMARY KEY (channel_id)
);

ALTER TABLE dim_user
    ADD FOREIGN KEY (signup_date) REFERENCES dim_date (date_sk);

ALTER TABLE summary_user
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);

ALTER TABLE summary_user
    ADD FOREIGN KEY (date_sk) REFERENCES dim_date (date_sk);

ALTER TABLE dim_user
    ADD FOREIGN KEY (channel_id) REFERENCES dim_channel (channel_id);
