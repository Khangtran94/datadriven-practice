CREATE TABLE dim_user (
    user_id INT,
    name CHAR,
    PRIMARY KEY (user_id)
);

CREATE TABLE ticket_lifecycle (
    ticket_id INT,
    agent_id INT,
    user_id INT,
    ticket_type_id INT,
    date_created INT,
    created_time TIMESTAMP,
    opened_time TIMESTAMP,
    processed_time TIMESTAMP,
    resolved_time TIMESTAMP,
    current_status CHAR,
    PRIMARY KEY (ticket_id)
);

CREATE TABLE dim_ticket_type (
    ticket_type_id INT,
    name CHAR,
    time_to_solve INT,
    PRIMARY KEY (ticket_type_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_agent (
    agent_id INT,
    name CHAR,
    description CHAR,
    PRIMARY KEY (agent_id)
);

CREATE TABLE status_log (
    log_id INT,
    ticket_id INT,
    status CHAR,
    changed_at TIMESTAMP,
    PRIMARY KEY (log_id)
);

ALTER TABLE ticket_lifecycle
    ADD FOREIGN KEY (date_created) REFERENCES dim_date (date_sk);

ALTER TABLE ticket_lifecycle
    ADD FOREIGN KEY (ticket_type_id) REFERENCES dim_ticket_type (ticket_type_id);

ALTER TABLE ticket_lifecycle
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);

ALTER TABLE ticket_lifecycle
    ADD FOREIGN KEY (agent_id) REFERENCES dim_agent (agent_id);

ALTER TABLE status_log
    ADD FOREIGN KEY (ticket_id) REFERENCES ticket_lifecycle (ticket_id);
