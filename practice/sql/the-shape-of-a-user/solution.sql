SELECT user_id,
    SUM(CASE WHEN event_type = 'search' THEN 1 ELSE 0 END) AS searches,
    SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS add_to_cart,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases
FROM event_data
GROUP BY 1
