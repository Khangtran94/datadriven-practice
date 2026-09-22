SELECT repo_name,	author
FROM code_reviews
ORDER BY comments DESC, review_id
LIMIT 3
