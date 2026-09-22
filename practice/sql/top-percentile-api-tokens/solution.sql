SELECT token_id, scope, requests,
      ROUND(PERCENT_RANK() OVER(PARTITION BY scope ORDER BY requests),2) AS percentile_rank
FROM api_tokens
WHERE requests IS NOT NULL
QUALIFY percentile_rank > 0.95
ORDER BY 3 desc
