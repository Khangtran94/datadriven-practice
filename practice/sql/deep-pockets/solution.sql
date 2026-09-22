select user_id, SUM(total_amount)
from transactions
where strftime('%Y-%m',transaction_date) = '2026-03'
GROUP BY 1 order by 2 desc
