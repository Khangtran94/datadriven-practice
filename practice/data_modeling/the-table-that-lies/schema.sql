CREATE TABLE dim_stylist (
    stylist_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (stylist_id)
);

CREATE TABLE dim_client (
    client_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (client_id)
);

CREATE TABLE session_log (
    session_id INT,
    session_date INT,
    stylist_id INT,
    client_id INT,
    status CHAR,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    PRIMARY KEY (session_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_item (
    item_id INT,
    item_name CHAR,
    PRIMARY KEY (item_id)
);

CREATE TABLE session_item (
    session_item_sk INT,
    session_id INT,
    item_id INT,
    quantity INT,
    unit_price DECIMAL,
    PRIMARY KEY (session_item_sk)
);

ALTER TABLE session_log
    ADD FOREIGN KEY (stylist_id) REFERENCES dim_stylist (stylist_id);

ALTER TABLE session_log
    ADD FOREIGN KEY (client_id) REFERENCES dim_client (client_id);

ALTER TABLE session_log
    ADD FOREIGN KEY (session_date) REFERENCES dim_date (date_sk);

ALTER TABLE session_item
    ADD FOREIGN KEY (item_id) REFERENCES dim_item (item_id);

ALTER TABLE session_item
    ADD FOREIGN KEY (session_id) REFERENCES session_log (session_id);
