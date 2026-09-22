














SELECT DISTINCT
  p.product_id,
  p.product_name
FROM products AS p
INNER JOIN transactions AS t
  ON p.product_id = t.product_id
WHERE t.transaction_date >= DATE('now', '-1 day')
UNION
SELECT
  product_id,
  product_name
FROM products
WHERE in_stock = 1
