SELECt repo_name, author, COUNT(*)
FROm repo_commits
WHERE message like '%fix%' and repo_name ILIKE '%data%'
GROUP By 1,2 
ORDER BY 3 desc
