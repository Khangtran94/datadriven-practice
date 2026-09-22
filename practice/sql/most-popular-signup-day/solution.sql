SELECT CASE WHEN EXTRACT(dow FROM signup_date) = 0 THEN 'Sunday'
          WHEN EXTRACT(dow FROM signup_date) = 1 THEN 'Monday'
          WHEN EXTRACT(dow FROM signup_date) = 2 THEN 'Tuesday'
          WHEN EXTRACT(dow FROM signup_date) = 3 THEN 'Wednesday'
          WHEN EXTRACT(dow FROM signup_date) = 4 THEN 'Thursday'
          WHEN EXTRACT(dow FROM signup_date) = 5 THEN 'Friday'
          ELSE 'Saturday' END AS signup_day, COUNT(*) AS signup_count
FROM users
GROUP BY EXTRACT(dow FROM signup_date)
ORDER BY 2 DESC
