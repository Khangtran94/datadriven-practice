CREATE TABLE dim_buyer (
    buyer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (buyer_id)
);

CREATE TABLE dim_property (
    property_id INT,
    neighborhood_id INT,
    name CHAR,
    property_type CHAR,
    PRIMARY KEY (property_id)
);

CREATE TABLE dim_neighborhood (
    neighborhood_id INT,
    city CHAR,
    state CHAR,
    PRIMARY KEY (neighborhood_id)
);

CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE fact_event (
    event_id INT,
    event_date DATE,
    event_time TIMESTAMP,
    buyer_id INT,
    property_id INT,
    action CHAR,
    PRIMARY KEY (event_id)
);

ALTER TABLE dim_property
    ADD FOREIGN KEY (neighborhood_id) REFERENCES dim_neighborhood (neighborhood_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_event
    ADD FOREIGN KEY (buyer_id) REFERENCES dim_buyer (buyer_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (property_id) REFERENCES dim_property (property_id);
