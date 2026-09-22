SELECT u.user_id, username, email, signup_date, account_status, age_bucket
FROM users AS u
LEFT JOIN user_sessions AS us 
ON u.user_id = us.user_id AND STRFTIME('%Y-%m',session_start) = '2026-03'
WHERE account_status = 'pending_verification' AND us.session_id IS NULL
