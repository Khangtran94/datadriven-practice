SELECT COUNT(*) AS total_commits,
    COUNT(DISTINCT LOWER(TRIM(author))) AS distinct_authors
fROM repo_commits
