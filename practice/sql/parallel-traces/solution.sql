SELECT DISTINCT a.user_id AS user_id1, b.user_id AS user_id2
FROM experiments AS a
INNER JOIN experiments AS b
ON a.exp_name = b.exp_name AND a.platform = b.platform
   AND a.variant <> b.variant AND a.user_id < b.user_id
