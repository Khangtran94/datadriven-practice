SELECT p.category, COUNT(t.transaction_id) AS txn_count,
      DENSE_RANK() OVER(ORDER BY COUNT(t.transaction_id) DESC) AS rnk
FROM products AS p
INNER JOIN transactions AS t
USING (product_id)
WHERE rating >= 3
GROUP BY 1
QUALIFY rnk <= 3
