with each AS
(SELECT user_id, ad_campaign, COUNT(*) AS cnt
FROM ad_impressions
where user_id is not null
GROUP BY 1,2),

combine AS
(SELECT user_id, 
    COUNT(ad_campaign) AS ads,
    sum(cnt) AS total
FROM each
GROUP BY 1)

SELECT user_id
FROM combine 
WHERE (ads = 1 AND total >= 3) OR (ads >= 2 AND total >= 5)
