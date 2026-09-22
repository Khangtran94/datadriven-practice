SELECT product_name, category, price, 
     case when in_stock != 0 then 'In Stock' Else 'Out of Stock' END AS availability
from products
where price is not null
order by 1 
