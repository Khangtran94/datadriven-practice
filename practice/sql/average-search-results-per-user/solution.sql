SELECT user_id, AVG(results_count)
FROM search_queries
WHERE user_id IS NOT NULL
GROUP BY 1
