select ad_campaign, 
      user_id, SUM(revenue) AS total_revenue
FROM ad_impressions
WHERE user_id IS NOT NULL and revenue is not null
group by 1,2 
QUALIFY DENSE_RANK() OVER(partition by ad_campaign order by total_revenue desc) = 1
order by 1,2, 3 desc
