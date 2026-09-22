SELECT * 
FROM ad_impressions
LEFT JOIN users using (user_id)
WHERE ad_campaign = 'HOLIDAY_PROMO'
