WITH total AS (
    SELECT
        repo_name,
        commit_at::timestamp AS commit_at,
        LEAD(commit_at::timestamp) OVER (PARTITION BY repo_name ORDER BY commit_at::timestamp) AS next_commit
    FROM repo_commits),
    
diff AS    
(SELECT
    *,
    ROUND(EXTRACT(EPOCH FROM (next_commit - commit_at)) / 86400,3) AS duration
FROM total
WHERE duration > 5),

each AS
(SELECT *
FROM diff
QUALIFY RANK() OVER(PARTITION BY repo_name ORDER BY duration DESC) = 1)

SELECT repo_name, duration AS longest_silence, 
      RANK() OVER(ORDER BY duration DESC) AS silence_rank
FROM each
