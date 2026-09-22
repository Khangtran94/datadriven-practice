WITH tbl_sums AS (
    SELECT
        tbl_name,
        SUM(fail_pct) AS total_fail_pct
    FROM dq_checks
    GROUP BY tbl_name
)
SELECT
    MAX(total_fail_pct) - MIN(total_fail_pct) AS dq_spread
FROM tbl_sums;
