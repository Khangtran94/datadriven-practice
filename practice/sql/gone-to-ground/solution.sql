SELECT u.user_id, 
      age_bucket, platform, variant
FROM experiments AS e
INNER JOIN users AS u 
USING (user_id)
WHERE account_status <> 'active'
      AND platform = 'android' AND variant = 'control'
