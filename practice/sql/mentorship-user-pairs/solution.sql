SELECT f.user_id AS user_id_1,
        s.user_id AS user_id_2
FROM users AS f
INNER JOIN users AS s 
ON f.user_id < s.user_id
WHERE f.age_bucket <> s.age_bucket
    AND f.account_status = s.account_status
    AND strftime('%Y',f.signup_date) <> strftime('%Y',s.signup_date)
    
  
