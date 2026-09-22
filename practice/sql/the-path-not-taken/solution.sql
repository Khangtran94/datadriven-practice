with total AS
(SELECT user_id, page_url, min(viewed_at) As see
FROM page_views
WHERE page_url IN ('new_editor','classic_editor')
GROUP BY 1,2),

new AS
(SELECT *, row_number() OVER(PARTITION BY user_id order by see) As rnk
FROM total)

SELECT user_id
FROM new
WHERE page_url = 'new_editor' AND rnk = 1
