CREATE TABLE fact_receipt_line (
    receipt_id INT,
    date_scanned INT,
    store_id INT,
    promotion_product_sk INT,
    total_amount DECIMAL,
    PRIMARY KEY (receipt_id)
);

CREATE TABLE dim_store (
    store_id INT,
    region_id INT,
    name CHAR,
    city CHAR,
    address CHAR,
    PRIMARY KEY (store_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_region (
    region_id INT,
    name CHAR,
    PRIMARY KEY (region_id)
);

CREATE TABLE dim_product (
    product_id INT,
    name CHAR,
    department_name INT,
    PRIMARY KEY (product_id)
);

CREATE TABLE dim_promotion (
    promotion_id INT,
    name CHAR,
    type CHAR,
    campaign_name CHAR,
    PRIMARY KEY (promotion_id)
);

CREATE TABLE bridge_promotion_product (
    promotion_product_sk INT,
    promotion_id INT,
    product_id INT,
    discount_rate DECIMAL,
    PRIMARY KEY (promotion_product_sk)
);

ALTER TABLE dim_store
    ADD FOREIGN KEY (region_id) REFERENCES dim_region (region_id);

ALTER TABLE fact_receipt_line
    ADD FOREIGN KEY (date_scanned) REFERENCES dim_date (date_sk);

ALTER TABLE bridge_promotion_product
    ADD FOREIGN KEY (product_id) REFERENCES dim_product (product_id);

ALTER TABLE bridge_promotion_product
    ADD FOREIGN KEY (promotion_id) REFERENCES dim_promotion (promotion_id);

ALTER TABLE fact_receipt_line
    ADD FOREIGN KEY (store_id) REFERENCES dim_store (store_id);

ALTER TABLE fact_receipt_line
    ADD FOREIGN KEY (promotion_product_sk) REFERENCES bridge_promotion_product (promotion_product_sk);
