SELECT distinct lower(author)
FROM deploy_logs
WHERE lower(status) ='success'
