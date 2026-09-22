SELECT extract(year from signup_date) AS signup_cohort,
      COUNT(query_id) AS total_searches, 
      COUNT(query_id) FILTER(WHERE clicked_result IS NOT NULL) AS successful_searches,
      ROUND(1.0 * COUNT(query_id) FILTER(WHERE clicked_result IS NOT NULL) / COUNT(query_id),3) AS success_rate
FROM users 
INNER JOIN search_queries
USING (user_id)
GROUP BY 1
