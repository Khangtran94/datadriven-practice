SELECT ad_campaign, COUNT(DISTINCT impression_id) AS impression_count
FROM ad_impressions
INNER JOIN push_notifs
USING (user_id)
WHERE lower(campaign) LIKE '%loyalty%'
GROUP BY ad_campaign
ORDER BY 2 desc
