SELECT endpoint,
      COUNT(*) AS total_calls,
      COUNT(*) FILTER(WHERE status LIKE '4%' OR status LIKE '5%') AS error_calls,
      ROUND(100.0 * COUNT(*) FILTER(WHERE status LIKE '4%' OR status LIKE '5%') / COUNT(*),2) AS error_rate
FROM api_calls
GROUP BY 1
HAVING total_calls >= 20
order by error_rate desc
