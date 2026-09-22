SELECT length(search_term) AS term_length,
        COUNT(*) AS query_count, 
        COUNT(clicked_result) FILTER(WHERE clicked_result = 1) AS clicked_count
FROM search_queries
GROUP BY 1 
ORDER BY 1
