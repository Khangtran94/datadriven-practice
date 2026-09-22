with cte AS
(SELECT category, 
    COUNT(*) AS total,
    COUNT(*) FILTER(WHERE NOT EXISTS(SELECT 1
                                      FROM transactions AS t
                                      WHERE t.product_id = p.product_id)) AS dead
FROM products AS p
GROUP BY category)

SELECT category, 100 * dead / total AS unsold_pct
FROM cte
