SELECT DISTINCT(author)
FROM deploy_logs
WHERE LOWER(author) = 'alice'
