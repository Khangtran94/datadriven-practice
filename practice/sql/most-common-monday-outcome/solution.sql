SELECT outcome, COUNT(*)
FROM experiments
WHERE strftime('%w',created) = '1'
GROUP BY 1
order by 2 desc
