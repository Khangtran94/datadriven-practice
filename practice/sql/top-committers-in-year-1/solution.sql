with month2025 AS
(SELECT strftime('%Y-%m',commit_at) AS mth, 
      author, SUM(added) AS add_mth
FROM repo_commits
WHERE extract(year from commit_at) = 2025
GROUP BY 1,2),

top10mth AS
(SELECT *,
    DENSE_RANK() OVER(PARTITION BY mth ORDER BY add_mth DESC) AS rnk
FROM month2025
QUALIFY rnk <= 10)

SELECT author, COUNT(*) AS top10_count
FROM top10mth
GROUP BY 1
order by 2 desc
limit 1
