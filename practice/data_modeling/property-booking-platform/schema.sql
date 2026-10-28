CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_property (
    property_id INT,
    host_id INT,
    name CHAR,
    type CHAR,
    PRIMARY KEY (property_id)
);

CREATE TABLE dim_host (
    host_id INT,
    signup_at DATE,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (host_id)
);

CREATE TABLE dim_guest (
    guest_id INT,
    signup_at DATE,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (guest_id)
);

CREATE TABLE event_log (
    event_id INT,
    event_date DATE,
    guest_id INT,
    property_id INT,
    number_day_booked DECIMAL,
    amount DECIMAL,
    PRIMARY KEY (event_id)
);

CREATE TABLE analysis (
    analysis_id INT,
    analysis_date DATE,
    event_id INT,
    guest_satisfaction_score DECIMAL,
    guest_review VARCHAR,
    property_score DECIMAL,
    rating DECIMAL,
    PRIMARY KEY (analysis_id)
);

ALTER TABLE dim_host
    ADD FOREIGN KEY (signup_at) REFERENCES dim_date (date_sk);

ALTER TABLE dim_guest
    ADD FOREIGN KEY (signup_at) REFERENCES dim_date (date_sk);

ALTER TABLE dim_property
    ADD FOREIGN KEY (host_id) REFERENCES dim_host (host_id);

ALTER TABLE event_log
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (date_sk);

ALTER TABLE event_log
    ADD FOREIGN KEY (guest_id) REFERENCES dim_guest (guest_id);

ALTER TABLE event_log
    ADD FOREIGN KEY (property_id) REFERENCES dim_property (property_id);

ALTER TABLE analysis
    ADD FOREIGN KEY (event_id) REFERENCES event_log (event_id);

ALTER TABLE analysis
    ADD FOREIGN KEY (analysis_date) REFERENCES dim_date (date_sk);
