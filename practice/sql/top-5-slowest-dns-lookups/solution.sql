SELECT DISTINCT domain, rec_type, latency,
  DENSE_RANK() OVER(ORDER BY latency DESC) AS rnk
FROM dns_lookups
QUALIFY DENSE_RANK() OVER(ORDER BY latency DESC) <= 5
