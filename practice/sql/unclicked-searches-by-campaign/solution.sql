SELECT ad_campaign, clicked_result, COUNT(*)
FROM search_queries
INNER JOIN ad_impressions USING(user_id)
GROUP BY 1,2
