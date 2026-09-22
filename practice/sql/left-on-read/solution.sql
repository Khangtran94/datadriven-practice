WITH campaign_opens AS (
    SELECT
        campaign,
        SUM(opened) AS open_count
    FROM push_notifs
    WHERE opened IS NOT NULL
      AND campaign IS NOT NULL
    GROUP BY campaign
)
SELECT
    campaign,
    open_count
FROM campaign_opens
WHERE open_count < (
    SELECT AVG(open_count)
    FROM campaign_opens
)
ORDER BY open_count;
