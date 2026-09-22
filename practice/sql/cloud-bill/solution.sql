




















	SELECT
	  category,
	  SUM(amount) AS total_amount,
	  COUNT(*) AS line_items,
	  AVG(amount) AS avg_cost_per_item
	FROM cost_allocs
	WHERE acct_id IS NOT NULL
	GROUP BY category
ORDER BY total_amount DESC
