CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_campaign (
    campaign_id INT,
    name CHAR,
    campaign_type CHAR,
    PRIMARY KEY (campaign_id)
);

CREATE TABLE dim_device (
    device_id INT,
    region_id INT,
    name CHAR,
    device_type CHAR,
    PRIMARY KEY (device_id)
);

CREATE TABLE dim_region (
    region_id INT,
    name CHAR,
    PRIMARY KEY (region_id)
);

CREATE TABLE fact_event (
    event_id INT,
    event_date DATE,
    ad_id INT,
    device_id INT,
    event_time TIMESTAMP,
    event_type CHAR,
    impression_id INT,
    PRIMARY KEY (event_id),
    UNIQUE (impression_id)
);

CREATE TABLE report_analytic (
    date_report DATE,
    ad_id INT,
    impression_count INT,
    click_count INT,
    conversion_count INT,
    PRIMARY KEY (date_report, ad_id)
);

CREATE TABLE dim_ad (
    ad_id INT,
    campaign_id INT,
    ad_name CHAR,
    PRIMARY KEY (ad_id)
);

CREATE TABLE fact_conversion (
    conversion_id INT,
    impression_id INT,
    amount DECIMAL,
    PRIMARY KEY (conversion_id)
);

ALTER TABLE dim_device
    ADD FOREIGN KEY (region_id) REFERENCES dim_region (region_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (device_id) REFERENCES dim_device (device_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (date_sk);

ALTER TABLE report_analytic
    ADD FOREIGN KEY (date_report) REFERENCES dim_date (date_sk);

ALTER TABLE dim_ad
    ADD FOREIGN KEY (campaign_id) REFERENCES dim_campaign (campaign_id);

ALTER TABLE report_analytic
    ADD FOREIGN KEY (ad_id) REFERENCES dim_ad (ad_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (ad_id) REFERENCES dim_ad (ad_id);

ALTER TABLE fact_conversion
    ADD FOREIGN KEY (impression_id) REFERENCES fact_event (impression_id);
