CREATE TABLE dim_team (
    team_id INT,
    office_id INT,
    manager_id INT,
    department_id INT,
    floor INT,
    name CHAR,
    number_members INT,
    PRIMARY KEY (team_id)
);

CREATE TABLE dim_manager (
    manager_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (manager_id)
);

CREATE TABLE dim_office (
    office_id INT,
    name CHAR,
    city CHAR,
    address CHAR,
    PRIMARY KEY (office_id)
);

CREATE TABLE dim_employee (
    employee_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    joined_at DATE,
    PRIMARY KEY (employee_id)
);

CREATE TABLE transfer_log (
    log_id INT,
    date_sk INT,
    employee_id INT,
    from_team_id INT,
    to_team_id INT,
    is_current BOOLEAN,
    PRIMARY KEY (log_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    day INT,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_org (
    org_id INT,
    name CHAR,
    PRIMARY KEY (org_id)
);

CREATE TABLE dim_division (
    division_id INT,
    org_id INT,
    name CHAR,
    PRIMARY KEY (division_id)
);

CREATE TABLE dim_department (
    department_id INT,
    division_id INT,
    name CHAR,
    PRIMARY KEY (department_id)
);

ALTER TABLE dim_team
    ADD FOREIGN KEY (office_id) REFERENCES dim_office (office_id);

ALTER TABLE dim_team
    ADD FOREIGN KEY (manager_id) REFERENCES dim_manager (manager_id);

ALTER TABLE transfer_log
    ADD FOREIGN KEY (employee_id) REFERENCES dim_employee (employee_id);

ALTER TABLE transfer_log
    ADD FOREIGN KEY (date_sk) REFERENCES dim_date (date_sk);

ALTER TABLE transfer_log
    ADD FOREIGN KEY (from_team_id) REFERENCES dim_team (team_id);

ALTER TABLE transfer_log
    ADD FOREIGN KEY (to_team_id) REFERENCES dim_team (team_id);

ALTER TABLE dim_team
    ADD FOREIGN KEY (department_id) REFERENCES dim_department (department_id);

ALTER TABLE dim_department
    ADD FOREIGN KEY (division_id) REFERENCES dim_division (division_id);

ALTER TABLE dim_division
    ADD FOREIGN KEY (org_id) REFERENCES dim_org (org_id);
