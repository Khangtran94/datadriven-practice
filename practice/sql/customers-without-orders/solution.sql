SELECT COUNT(customer_id)
FROM customers
WHERE NOT EXISTS (SELECT 1 FROM transactions
              WHERE customers.customer_id = transactions.user_id)
