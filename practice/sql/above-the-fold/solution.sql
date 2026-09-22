SELECT
    query_id,
    CASE
        WHEN clicked_result IS NULL THEN NULL
        WHEN clicked_result <= 3 THEN 3
        ELSE 2
    END AS rating
FROM search_queries;
