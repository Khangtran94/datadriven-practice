CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_shopper (
    shopper_id INT,
    signup_date DATE,
    shopper_account CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (shopper_id)
);

CREATE TABLE dim_device (
    device_id INT,
    signup_at DATE,
    device_type CHAR,
    brand CHAR,
    PRIMARY KEY (device_id)
);

CREATE TABLE fact_event (
    event_id INT,
    product_id INT,
    session_id INT,
    element_id INT,
    page_id INT,
    event_time TIMESTAMP,
    action_type CHAR,
    link_URL CHAR,
    color CHAR,
    size CHAR,
    PRIMARY KEY (event_id)
);

CREATE TABLE fact_session (
    session_id INT,
    session_date DATE,
    shopper_id INT,
    device_id INT,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    is_purchased BOOLEAN,
    event_count INT,
    product_views INT,
    PRIMARY KEY (session_id)
);

CREATE TABLE dim_product (
    product_id INT,
    name CHAR,
    genre CHAR,
    PRIMARY KEY (product_id)
);

CREATE TABLE dim_page (
    page_id INT,
    page_url CHAR,
    page_type CHAR,
    PRIMARY KEY (page_id)
);

CREATE TABLE dim_element (
    element_id INT,
    name CHAR,
    type CHAR,
    PRIMARY KEY (element_id)
);

ALTER TABLE dim_shopper
    ADD FOREIGN KEY (signup_date) REFERENCES dim_date (date_sk);

ALTER TABLE dim_device
    ADD FOREIGN KEY (signup_at) REFERENCES dim_date (date_sk);

ALTER TABLE fact_session
    ADD FOREIGN KEY (session_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_session
    ADD FOREIGN KEY (shopper_id) REFERENCES dim_shopper (shopper_id);

ALTER TABLE fact_session
    ADD FOREIGN KEY (device_id) REFERENCES dim_device (device_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (session_id) REFERENCES fact_session (session_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (product_id) REFERENCES dim_product (product_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (page_id) REFERENCES dim_page (page_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (element_id) REFERENCES dim_element (element_id);
