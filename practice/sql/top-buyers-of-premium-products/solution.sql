with combine AS
(SELECT category, 
    COUNT(DISTINCT user_id) AS buyer_count
FROM order_items
INNER JOIN products
USING (product_id)
WHERE rating >= 4
GROUP BY 1
ORDER BY 2 desc)

SELECT *, DENSE_RANK() OVER(ORDER BY buyer_count DESC) AS rank_pos
FROM combine
ORDER BY 3, 1
