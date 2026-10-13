CREATE TABLE order_item (
    order_item_id INT,
    item_id INT,
    order_id INT,
    quantity INT,
    amount INT,
    PRIMARY KEY (order_item_id)
);

CREATE TABLE dim_order (
    order_id INT,
    order_date INT,
    customer_id INT,
    PRIMARY KEY (order_id)
);

CREATE TABLE dim_customer (
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (customer_id)
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
    name CHAR,
    PRIMARY KEY (item_id)
);

CREATE TABLE shipment (
    shipment_id INT,
    current_status CHAR,
    center_id INT,
    order_item_id INT,
    PRIMARY KEY (shipment_id)
);

CREATE TABLE dim_center (
    center_id INT,
    name CHAR,
    address CHAR,
    PRIMARY KEY (center_id)
);

CREATE TABLE shipment_event (
    event_id INT,
    shipment_id INT,
    event_type CHAR,
    event_ts TIMESTAMP,
    PRIMARY KEY (event_id)
);

ALTER TABLE dim_order
    ADD FOREIGN KEY (customer_id) REFERENCES dim_customer (customer_id);

ALTER TABLE dim_order
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);

ALTER TABLE order_item
    ADD FOREIGN KEY (item_id) REFERENCES dim_item (item_id);

ALTER TABLE order_item
    ADD FOREIGN KEY (order_id) REFERENCES dim_order (order_id);

ALTER TABLE shipment
    ADD FOREIGN KEY (center_id) REFERENCES dim_center (center_id);

ALTER TABLE shipment
    ADD FOREIGN KEY (order_item_id) REFERENCES order_item (order_item_id);

ALTER TABLE shipment_event
    ADD FOREIGN KEY (shipment_id) REFERENCES shipment (shipment_id);
