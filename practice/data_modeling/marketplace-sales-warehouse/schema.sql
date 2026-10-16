CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_account (
    account_sk INT,
    account_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    region CHAR,
    effective_from DATE,
    effective_to DATE,
    is_current BOOLEAN,
    PRIMARY KEY (account_sk)
);

CREATE TABLE dim_product (
    product_id INT,
    category_id INT,
    name CHAR,
    PRIMARY KEY (product_id)
);

CREATE TABLE dim_category (
    category_id INT,
    name CHAR,
    parent_category_id INT,
    PRIMARY KEY (category_id)
);

CREATE TABLE fact_order_line (
    order_line_id INT,
    order_id INT,
    product_id INT,
    seller_id INT,
    quantity INT,
    unit_price DECIMAL,
    order_date INT,
    commission_rate DECIMAL,
    PRIMARY KEY (order_line_id)
);

CREATE TABLE order_table (
    order_id INT,
    order_date INT,
    buyer_id INT,
    estimated_amount DECIMAL,
    PRIMARY KEY (order_id)
);

ALTER TABLE dim_product
    ADD FOREIGN KEY (category_id) REFERENCES dim_category (category_id);

ALTER TABLE order_table
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_order_line
    ADD FOREIGN KEY (order_id) REFERENCES order_table (order_id);

ALTER TABLE fact_order_line
    ADD FOREIGN KEY (product_id) REFERENCES dim_product (product_id);

ALTER TABLE order_table
    ADD FOREIGN KEY (buyer_id) REFERENCES dim_account (account_sk);

ALTER TABLE fact_order_line
    ADD FOREIGN KEY (seller_id) REFERENCES dim_account (account_sk);
