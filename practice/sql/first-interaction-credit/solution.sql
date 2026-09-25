with new AS
(SELECT user_id, MIN(impression_time) AS impression_time
FROM ad_impressions
WHERE exists (SELECT 1 FROM transactions WHERE ad_impressions.user_id = transactions.user_id)
GROUP BY 1)

SELECT n.user_id, a.ad_campaign, n.impression_time
FROM new AS n
INNER JOIN ad_impressions AS a
ON n.user_id = a.user_id AND n.impression_time = a.impression_time
ORDER By 1
