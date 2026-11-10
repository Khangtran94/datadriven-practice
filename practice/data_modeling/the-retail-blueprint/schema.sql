CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_product (
    product_id INT,
    name CHAR,
    category CHAR,
    price DECIMAL,
    PRIMARY KEY (product_id)
);

CREATE TABLE dim_channel (
    channel_id INT,
    channel_type CHAR,
    channel_name CHAR,
    PRIMARY KEY (channel_id)
);

CREATE TABLE dim_customer (
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    membership_tier CHAR,
    city CHAR,
    country CHAR,
    PRIMARY KEY (customer_id)
);

CREATE TABLE fact_order (
    order_id INT,
    order_date INT,
    channel_id INT,
    customer_id INT,
    product_id INT,
    quantity INT,
    total_amount DECIMAL,
    PRIMARY KEY (order_id)
);

ALTER TABLE fact_order
    ADD FOREIGN KEY (product_id) REFERENCES dim_product (product_id);

ALTER TABLE fact_order
    ADD FOREIGN KEY (channel_id) REFERENCES dim_channel (channel_id);

ALTER TABLE fact_order
    ADD FOREIGN KEY (customer_id) REFERENCES dim_customer (customer_id);

ALTER TABLE fact_order
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);
