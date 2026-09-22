WITH branches AS (
    SELECT 'main' AS branch
    UNION ALL
    SELECT 'release' AS branch
),

year AS (
    SELECT *
    FROM ci_builds
    WHERE EXTRACT(YEAR FROM built_at) = 2026
      AND trigger != 'manual'
)

SELECT
    b.branch,
    COUNT(y.branch) AS build_count,
    COUNT(y.branch)::DECIMAL AS build_count_decimal,
    AVG(y.dur_secs) AS avg_duration
FROM branches b
LEFT JOIN year y
    ON b.branch = y.branch
GROUP BY b.branch
ORDER BY b.branch;
