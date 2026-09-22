with topuser AS
(SELECT reviewer, COUNT(*) AS cnt
FROM code_reviews
WHERE merged IS NOT NULL
GROUP BY reviewer)

SELECT reviewer,
        COUNT(DISTINCT repo_name) AS reviewed_count,
        COUNT(DISTINCT repo_name) AS merged_count, 
        MAX(opened_at) AS latest_review_date
FROM code_reviews
WHERE merged IS NOT NULL 
    AND EXISTS (SELECT 1 FROM topuser WHERE code_reviews.reviewer = topuser.reviewer)
GROUP BY 1
ORDER BY 1
