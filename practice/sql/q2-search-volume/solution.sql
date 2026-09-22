SELECT COUNT(*)
FROM search_queries
WHERE extract(quarter from query_time) = 2
AND extract(year from query_time) = 2026
