select transaction_date, total_amount as net_revenue
FROM transactions 
where product_id = 1001
order by transaction_date
