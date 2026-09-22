with new As
(SELECT owner_id, scope, SUM(requests)
FROM api_tokens
GROUP BY 1,2
ORDER BY 3 desc)

SELECT scope 
FROM new
limit 2
