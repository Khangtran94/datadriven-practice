select ad_campaign, sum(revenue) as total_revenue
FROM ad_impressions
where revenue is not null or lower(ad_campaign) not like '%test%'
GROUP BY 1 
order by 2 desc
limit 2
