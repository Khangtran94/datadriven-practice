SELECT extract(dow from sent_at) AS day_of_week,
    COUNT(*) FILTER(WHERE lower(platform) = 'ios') AS ios_count,
    COUNT(*) FILTER(WHERE lower(platform) = 'android') AS android_count,
    COUNT(*) FILTER(WHERE lower(platform) = 'web') AS web_count
FROM push_notifs
GROUP BY 1
