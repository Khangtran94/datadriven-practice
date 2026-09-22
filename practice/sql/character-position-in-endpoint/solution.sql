SELECT endpoint,2 AS a_position
FROM api_calls
WHERE LOWER(SUBSTRING(endpoint,2,1)) = 'a'
