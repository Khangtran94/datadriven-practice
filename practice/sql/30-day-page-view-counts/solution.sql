SELECT user_id, COUNT(*) AS total_views
FROM page_views
WHERE viewed_at BETWEEN DATE_ADD('day', -30, DATE '2026-12-28')
                    AND DATE '2026-12-28'
GROUP BY user_id;
