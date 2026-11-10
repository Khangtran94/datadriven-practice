CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_customer (
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    tier CHAR,
    PRIMARY KEY (customer_id)
);

CREATE TABLE dim_product (
    product_id INT,
    name CHAR,
    price DECIMAL,
    type CHAR,
    PRIMARY KEY (product_id)
);

CREATE TABLE fact_order (
    order_id INT,
    order_date INT,
    customer_id INT,
    product_id INT,
    quantity INT,
    total_amount DECIMAL,
    PRIMARY KEY (order_id)
);

ALTER TABLE fact_order
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_order
    ADD FOREIGN KEY (customer_id) REFERENCES dim_customer (customer_id);

ALTER TABLE fact_order
    ADD FOREIGN KEY (product_id) REFERENCES dim_product (product_id);
