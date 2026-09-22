SELECT 
    category,
    ROUND(AVG(rating), 1) AS avg_rating
FROM products
WHERE rating IS NOT NULL
GROUP BY category
-- HAVING COUNT(*) < 3
ORDER BY avg_rating DESC;
