CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_order (
    order_id INT,
    order_date DATE,
    customer_id TEXT,  /* no type on the canvas */
    total_amount DECIMAL,
    PRIMARY KEY (order_id)
);

CREATE TABLE dim_date_copy (
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (customer_id)
);

CREATE TABLE dim_item (
    item_id INT,
    name CHAR,
    price DECIMAL,
    PRIMARY KEY (item_id)
);

CREATE TABLE order_line_item (
    order_item_id INT,
    item_id INT,
    order_id INT,
    quantity TEXT,  /* no type on the canvas */
    PRIMARY KEY (order_item_id)
);

CREATE TABLE package (
    package_id INT,
    warehouse_id INT,
    order_item_id INT,
    current_status CHAR,
    PRIMARY KEY (package_id)
);

CREATE TABLE dim_warehouse (
    warehouse_id INT,
    name CHAR,
    address CHAR,
    city CHAR,
    PRIMARY KEY (warehouse_id)
);

CREATE TABLE package_event (
    event_id INT,
    package_id INT,
    event_type CHAR,
    event_time TIMESTAMP,
    PRIMARY KEY (event_id)
);

ALTER TABLE dim_order
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);

ALTER TABLE dim_order
    ADD FOREIGN KEY (customer_id) REFERENCES dim_date_copy (customer_id);

ALTER TABLE order_line_item
    ADD FOREIGN KEY (item_id) REFERENCES dim_item (item_id);

ALTER TABLE order_line_item
    ADD FOREIGN KEY (order_id) REFERENCES dim_order (order_id);

ALTER TABLE package
    ADD FOREIGN KEY (warehouse_id) REFERENCES dim_warehouse (warehouse_id);

ALTER TABLE package
    ADD FOREIGN KEY (order_item_id) REFERENCES order_line_item (order_item_id);

ALTER TABLE package_event
    ADD FOREIGN KEY (package_id) REFERENCES package (package_id);
