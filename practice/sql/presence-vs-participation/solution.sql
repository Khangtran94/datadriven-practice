SELECT 
    CASE 
        WHEN 
            (SELECT COUNT(*) FROM users WHERE account_status = 'active')
            -
            (SELECT COUNT(*) FROM infra_nodes WHERE region = 'us-east-1') > 0
        THEN 'More active'
        ELSE 'More us-east-1'
    END AS result;
