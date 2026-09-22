SELECT DISTINCT
  ai.ad_campaign,
  pn.campaign AS push_campaign
FROM ad_impressions AS ai
INNER JOIN push_notifs AS pn
  ON (
  LOWER(ai.ad_campaign) LIKE '%flash%'
  AND LOWER(pn.campaign) LIKE '%flash%'
)
  OR (
  LOWER(ai.ad_campaign) LIKE '%loyalty%'
  AND LOWER(pn.campaign) LIKE '%loyalty%'
)
  OR (
  LOWER(ai.ad_campaign) LIKE '%summer%'
  AND LOWER(pn.campaign) LIKE '%summer%'
)
ORDER BY ai.ad_campaign
