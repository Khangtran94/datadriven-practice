with new AS
(SELECT * FROM products WHERE in_stock = 1 AND rating >= 4)

SELECT 100.0 * (SELECT COUNT(*) FROM new) / COUNT(*) AS pct_in_stock_high_rated
FROM products
