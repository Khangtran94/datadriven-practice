


select count(distinct owner_id)
FROM api_tokens
where scope not like 'read%'
