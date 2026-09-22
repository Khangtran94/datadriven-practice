with top3 AS
(SELECT user_id, page_url, 
      ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY viewed_at) AS rnk
FROM page_views),

user3 AS (SELECT * FROM top3 WHERE rnk <= 3),

alluser AS (SELECT page_url, COUNT(*) AS appearance_count,
      DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS rnk
FROM user3 GROUP BY page_url)

SELECT page_url, appearance_count
FROM alluser 
WHERE rnk <= 3
