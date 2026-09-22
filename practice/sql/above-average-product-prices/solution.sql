with base AS
(SELECT product_id, 
      MIN(total_amount) AS base_price
FROM transactions
GROUP BY product_id)

SELECT product_id, base_price
FROM base
WHERE base_price > (SELECT AVG(base_price) FROM base)
