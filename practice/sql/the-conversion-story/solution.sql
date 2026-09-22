SELECT 
      CASE WHEN CONTAINS(tags,'organic') THEN 'organic' 
          WHEN CONTAINS(tags,'referral') THEN 'referral' 
          WHEN CONTAINS(tags,'campaign_a') THEN 'campaign_a' 
          WHEN CONTAINS(tags,'campaign_b') THEN 'campaign_b' 
      ELSE 'other' END AS referral_source,
      COUNT(DISTINCT user_id) FILTER(WHERE event_type = 'signup') AS signup_count,
      COUNT(DISTINCT user_id) FILTER(WHERE event_type = 'purchase') AS purchase_count, 
      1.0 * COUNT(DISTINCT user_id) FILTER(WHERE event_type = 'purchase') / COUNT(DISTINCT user_id) FILTER(WHERE event_type = 'signup') AS conversion_rate
FROM event_data
GROUP BY 1
HAVING signup_count > 0
