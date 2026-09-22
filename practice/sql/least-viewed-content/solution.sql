SELECT page_url AS content_id, 
      COUNT(DISTINCT user_id) AS unique_viewers
FROM page_views
GROUP BY 1
QUALIFY DENSE_RANK() OVER(ORDER BY unique_viewers) = 1
