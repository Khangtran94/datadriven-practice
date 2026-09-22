SELECT endpoint, 
      SUM(CASE WHEN err_msg IS NULL THEN 1 END) AS no_error_count,
      COUNT(*) - SUM(CASE WHEN err_msg IS NULL THEN 1 END) AS error_count, 
      COUNT(*)
FROM api_calls
GROUP By 1
