SELECT username, 
      COALESCE(email,'unknown') AS email,
      COALESCE(age_bucket,'unspecified') AS age_bucket
FROM users
WHERE account_status = 'active'
