SELECT author, message, LENGTH(message) AS length_message
FROM repo_commits
WHERE message IS NOT NULL AND length_message > 10
