CREATE TABLE dim_plate (
    plate_id INT,
    plate_character CHAR,
    car_brand CHAR,
    car_color CHAR,
    PRIMARY KEY (plate_id)
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
    plate_id INT,
    section_id INT,
    entry_time TIMESTAMP,
    exit_time TIMESTAMP,
    exit_status BOOLEAN,
    PRIMARY KEY (event_id)
);

CREATE TABLE dim_section (
    section_id INT,
    section_name CHAR,
    location CHAR,
    PRIMARY KEY (section_id)
);

ALTER TABLE fact_event
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_event
    ADD FOREIGN KEY (plate_id) REFERENCES dim_plate (plate_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (section_id) REFERENCES dim_section (section_id);
