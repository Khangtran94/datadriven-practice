with new AS
(SELECT svc_name, COUNT(DISTINCT author)
FROM deploy_logs
where lower(author) like 'a%'
GROUP BY 1 order by 2 desc)

SELECT distinct svc_name, author
FROM deploy_logs
WHERE svc_name IN (SELECT svc_name from new) 
    AND lower(author) like 'a%'
ORDER BY 1, 2
