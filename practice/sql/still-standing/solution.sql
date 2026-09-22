select token_id, issued
FROM api_tokens
where expires is null  OR expires > DATE('now')
order by requests desc
limit 5
