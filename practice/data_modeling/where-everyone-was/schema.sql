CREATE TABLE customer (
    customer_sk INT,
    customer_id INT,
    name VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    PRIMARY KEY (customer_sk)
);

CREATE TABLE customer_addresses (
    fact_id INT,
    address_id INT,
    customer_sk INT,
    valid_from DATE,
    valid_to DATE,
    is_current BOOLEAN,
    PRIMARY KEY (fact_id)
);

CREATE TABLE address (
    address_id INT,
    street VARCHAR,
    city VARCHAR,
    zip VARCHAR,
    country VARCHAR,
    PRIMARY KEY (address_id)
);

ALTER TABLE customer_addresses
    ADD FOREIGN KEY (customer_sk) REFERENCES customer (customer_sk);

ALTER TABLE customer_addresses
    ADD FOREIGN KEY (address_id) REFERENCES address (address_id);
