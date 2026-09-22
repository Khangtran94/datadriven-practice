SELECT min(latency), max(latency),
      SUM(CASE WHEN latency != (SELECT MIN(latency) FROM api_calls)
              AND latency != (SELECT MAX(latency) FROM api_calls) 
              THEN latency else 0 end) AS sum_between
FROM api_calls
