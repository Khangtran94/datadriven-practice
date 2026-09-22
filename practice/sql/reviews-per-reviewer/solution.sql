SELECT reviewer, 
    COUNT(*) AS review_count
FROM code_reviews
GROUP BY reviewer
