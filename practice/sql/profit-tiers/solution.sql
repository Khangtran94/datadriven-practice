select case when profit > 100 then 'high' 
            when profit >= 0 then 'moderate'
            else 'negative' end as tier,
            COUNT(*) AS order_count
 FROM orders
 GROUP BY tier
