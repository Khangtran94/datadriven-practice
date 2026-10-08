CREATE TABLE customer (
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (customer_id)
);

CREATE TABLE address (
    address_id INT,
    street CHAR,
    city CHAR,
    country CHAR,
    PRIMARY KEY (address_id)
);

CREATE TABLE history (
    change_id INT,
    customer_id INT,
    address_id INT,
    is_active BOOLEAN,
    effective_from DATE,
    effective_to DATE,
    PRIMARY KEY (change_id)
);

ALTER TABLE history
    ADD FOREIGN KEY (address_id) REFERENCES address (address_id);

ALTER TABLE history
    ADD FOREIGN KEY (customer_id) REFERENCES customer (customer_id);
