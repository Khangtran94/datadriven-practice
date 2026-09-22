SELECT COUNT(*) AS repeat_searcher_count
FROM (SELECT user_id FROM search_queries
    WHERE strftime('%Y',query_time) = '2026'
    GROUP BY user_id
    HAVING COUNT(*) > 1)
