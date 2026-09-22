SELECT EXTRACT(day from impression_time) AS day_of_month,
    AVG(revenue) AS avg_revenue,
    MAX(revenue) AS max_revenue,
    AVG(
    CASE
      WHEN clicked = 1 THEN revenue
    END
    ) - AVG(
    CASE
      WHEN clicked = 0 THEN revenue
    END
    ) AS click_premium
FROM ad_impressions
GROUP BY day_of_month
ORDER BY click_premium DESC, day_of_month
