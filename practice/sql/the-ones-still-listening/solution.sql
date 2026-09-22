SELECT 100.0 * COUNT(*) FILTER(WHERE opened > 0 AND account_status = 'active') / COUNT(*) AS active_opened_pct 
FROM push_notifs
INNER JOIN users
USING (user_id)
