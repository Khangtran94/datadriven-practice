select category, sum(amount)
FROM cost_allocs
group by 1
