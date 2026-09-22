SELECT tbl_name, col_name, COUNT(*) AS duplicate_count,
      RANK() OVER(ORDER BY COUNT(*) DESC) AS dup_rank,
      100.0 * COUNT(*) / (SELECT COUNT(*) FROM dq_checks) AS pct_of_dups
FROM dq_checks
GROUP BY 1, 2
ORDER By 3 DESC
