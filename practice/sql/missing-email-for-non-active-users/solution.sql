SELECT user_id
FROm users
WHERE extract(year from signup_date) = 2026 AND account_status != 'active'
      and (email IS NULL OR email = '')
