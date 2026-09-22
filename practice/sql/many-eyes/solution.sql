SELECT repo_name, 
      EXTRACT(year from opened_at) AS review_year, 
      COUNT(distinct reviewer) AS reviewer_count
FROM code_reviews
where reviewer is not null
GROUP BY 1,2 
order by 3 desc
