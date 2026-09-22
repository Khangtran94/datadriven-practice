SELECT trigger, COUNT(*) AS build_count, 
      AVG(dur_secs)
FROM ci_builds
GROUP BY 1
ORDER By 1
