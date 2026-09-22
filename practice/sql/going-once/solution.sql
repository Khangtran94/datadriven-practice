WITH ranked AS (
    SELECT
        p.product_id,
        p.product_name,
        t.user_id AS winner,
        t.total_amount,
        COUNT(t.transaction_id) OVER (PARTITION BY p.product_id) AS bid_count,
        ROW_NUMBER() OVER (
            PARTITION BY p.product_id
            ORDER BY t.total_amount DESC
        ) AS rn
    FROM products p
    LEFT JOIN transactions t USING (product_id)
    WHERE p.in_stock <> 0
)
SELECT
    product_id,
    product_name,
    bid_count,
    total_amount AS highest_bid,
    winner
FROM ranked
WHERE rn = 1;
