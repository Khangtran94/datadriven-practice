with total AS
(SELECT author, version, applied, migr_id,
      DENSE_RANK() OVER(PARTITION BY author ORDER BY applied DESC, migr_id DESC) AS rnk
FROM migrations
QUALIFY DENSE_RANK() OVER(PARTITION BY author ORDER BY applied DESC, migr_id DESC) = 1)

SELECT author, version, applied
FROM total ORDER BY author
