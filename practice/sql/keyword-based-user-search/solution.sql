SELECT DISTINCT user_id
FROM search_queries
WHERE LOWER(search_term) LIKE '%desk%'
    OR LOWER(search_term) LIKE '%monitor%'
    OR LOWER(search_term) LIKE '%cable%'
    OR LOWER(search_term) LIKE '%mouse%'
