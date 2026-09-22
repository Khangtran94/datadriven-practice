SELECT
    p.product_name,
    p.category,
    t.total_amount AS latest_sale_amount,
    t.transaction_date AS last_sale_date
FROM products p
JOIN transactions t
    ON p.product_id = t.product_id
WHERE (t.product_id, t.transaction_date) IN (
    SELECT
        product_id,
        MAX(transaction_date)
    FROM transactions
    GROUP BY product_id
);
