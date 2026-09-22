SELECT priority, 
      COUNT(*) FILTER (WHERE retries = 0) AS zero_retry_count, 
      COUNT(*) AS total_jobs, 
      1.0 * COUNT(*) FILTER (WHERE retries = 0) / COUNT(*) AS ratio
FROM batch_jobs
GROUP BY 1
ORDER BY ratio 
