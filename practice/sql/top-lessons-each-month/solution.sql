with total AS
(SELECT strftime('%Y-%m',viewed_at) AS month, 
      page_url, COUNT(*) AS completion_count
FROM page_views
GROUP BY 1,2)

SELECT *, RANK() OVER(PARTITION BY month ORDER BY completion_count DESC) AS rnk
FROM total
QUALIFY rnk <= 3
