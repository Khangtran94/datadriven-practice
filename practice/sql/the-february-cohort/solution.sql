SELECT *
FROM users
WHERE strftime('%Y-%m',signup_date) = '2025-02'
