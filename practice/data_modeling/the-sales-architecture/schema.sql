CREATE TABLE dim_date (
    date_sk DATE,
    month TEXT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_product (
    product_id INT,
    name CHAR,
    genre CHAR,
    price DECIMAL,
    PRIMARY KEY (product_id)
);

CREATE TABLE dim_seller (
    seller_id INT,
    region_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    signup_at DATE,
    PRIMARY KEY (seller_id)
);

CREATE TABLE dim_customer (
    customer_id INT,
    region_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    signup_at DATE,
    PRIMARY KEY (customer_id)
);

CREATE TABLE dim_region (
    region_id INT,
    name CHAR,
    PRIMARY KEY (region_id)
);

CREATE TABLE fact_transaction (
    event_id INT,
    event_date DATE,
    event_time TIMESTAMP,
    product_id INT,
    event_type CHAR,
    seller_id INT,
    customer_id INT,
    quantity INT,
    amount DECIMAL,
    PRIMARY KEY (event_id)
);

ALTER TABLE dim_seller
    ADD FOREIGN KEY (region_id) REFERENCES dim_region (region_id);

ALTER TABLE dim_customer
    ADD FOREIGN KEY (region_id) REFERENCES dim_region (region_id);

ALTER TABLE fact_transaction
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_transaction
    ADD FOREIGN KEY (product_id) REFERENCES dim_product (product_id);

ALTER TABLE fact_transaction
    ADD FOREIGN KEY (seller_id) REFERENCES dim_seller (seller_id);

ALTER TABLE fact_transaction
    ADD FOREIGN KEY (customer_id) REFERENCES dim_customer (customer_id);
