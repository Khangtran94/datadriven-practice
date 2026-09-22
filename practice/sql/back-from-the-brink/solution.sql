with normal AS
(SELECT lower(author) as author, 
        lower(status) AS status,
        deploy_at
FROM deploy_logs
ORDER BY 1,2,3),

island AS
(SELECT *, 
      LAG(status) OVER(PARTITION BY author order by deploy_at) AS prev_status
FROM normal)

SELECT COUNT(distinct author) AS recovery_count
FROM island
WHERE prev_status = 'rolled_back' AND status = 'success'
