select COUNT(*)
from users where extract(year from signup_date) = 2026
