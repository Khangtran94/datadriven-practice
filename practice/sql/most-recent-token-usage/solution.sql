SELECT *, row_number() OVER(PARTITION BY owner_id ORDER BY last_used DESC)
FROM api_tokens
qualify row_number() OVER(PARTITION BY owner_id ORDER BY last_used DESC) = 1
