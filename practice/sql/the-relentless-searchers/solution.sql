SELECT user_id, COUNT(*) As query_count,
    RANK() OVER(ORDER BY COUNT(*) DESC, user_id::text) AS rnk
FROM search_queries
GROUP BY 1
