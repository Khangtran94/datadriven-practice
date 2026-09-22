SELECT *
FROM search_queries
WHERE LENGTH(search_term) > 12 AND LOWER(search_term) LIKE '%r'
ORDER BY query_id
