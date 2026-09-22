SELECT COUNT(*) AS query_count
FROM search_queries
WHERE LOWER(search_term) LIKE '%monitor%'
