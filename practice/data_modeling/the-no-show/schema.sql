CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_member (
    member_id INT,
    name DATE,
    phone INT,
    email INT,
    PRIMARY KEY (member_id)
);

CREATE TABLE dim_tier (
    tier_id INT,
    name CHAR,
    monthly_fee DECIMAL,
    number_of_class INT,
    PRIMARY KEY (tier_id)
);

CREATE TABLE member_tier (
    member_tier_sk INT,
    member_id INT,
    tier_id INT,
    from_date DATE,
    to_date DATE,
    is_current BOOLEAN,
    PRIMARY KEY (member_tier_sk, member_id, tier_id)
);

CREATE TABLE session (
    session_id INT,
    studio_id INT,
    date_started DATE,
    PRIMARY KEY (session_id)
);

CREATE TABLE dim_studio (
    studio_id INT,
    name CHAR,
    PRIMARY KEY (studio_id)
);

CREATE TABLE booking (
    booking_id INT,
    session_id INT,
    member_tier_sk INT,
    booking_status CHAR,
    checkin_time TIMESTAMP,
    PRIMARY KEY (booking_id)
);

ALTER TABLE member_tier
    ADD FOREIGN KEY (member_id) REFERENCES dim_member (member_id);

ALTER TABLE member_tier
    ADD FOREIGN KEY (tier_id) REFERENCES dim_tier (tier_id);

ALTER TABLE session
    ADD FOREIGN KEY (studio_id) REFERENCES dim_studio (studio_id);

ALTER TABLE session
    ADD FOREIGN KEY (date_started) REFERENCES dim_date (date_sk);

ALTER TABLE booking
    ADD FOREIGN KEY (session_id) REFERENCES session (session_id);

ALTER TABLE booking
    ADD FOREIGN KEY (member_tier_sk) REFERENCES member_tier (member_tier_sk);
