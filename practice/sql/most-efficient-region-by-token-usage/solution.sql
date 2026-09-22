SELECT scope AS region, 
      365 AS avg_lifetime_days,
      AVG(requests) AS avg_requests,
      AVG(requests) / 365 AS requests_per_day_ratio
FROM api_tokens
where expires is not null
GROUP BY region
ORDER BY 4 desc
