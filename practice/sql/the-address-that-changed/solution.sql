with dup AS
(SELECT customer_id, count(*)
from customers 
GROUP BY 1
having count(*) > 1)

SELECT customer_id, first_name,
    country AS current_city, 
    COUNT(*) AS move_count
FROM customers
WHERE customer_id IN (SELECT customer_id FROM dup)
GROUP By 1,2,3
