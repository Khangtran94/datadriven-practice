CREATE TABLE dim_user (
    user_id INT,
    signup_at DATE,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (user_id)
);

CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_vehicle (
    vehicle_id INT,
    vehicle_type CHAR,
    brand CHAR,
    license_plate CHAR,
    PRIMARY KEY (vehicle_id)
);

CREATE TABLE dim_trip (
    trip_id INT,
    from_place CHAR,
    to_place CHAR,
    fare_charged DECIMAL,
    PRIMARY KEY (trip_id)
);

CREATE TABLE fact_event (
    event_id INT,
    event_date DATE,
    trip_id INT,
    driver_id INT,
    rider_id INT,
    vehicle_id INT,
    direction CHAR,
    surge_mutliplier DECIMAL,
    rating DECIMAL,
    PRIMARY KEY (event_id)
);

ALTER TABLE dim_user
    ADD FOREIGN KEY (signup_at) REFERENCES dim_date (date_sk);

ALTER TABLE fact_event
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_event
    ADD FOREIGN KEY (trip_id) REFERENCES dim_trip (trip_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (driver_id) REFERENCES dim_user (user_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (rider_id) REFERENCES dim_user (user_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (vehicle_id) REFERENCES dim_vehicle (vehicle_id);
