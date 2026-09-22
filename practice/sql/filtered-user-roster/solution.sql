SELECT *
FROm users
WHERE username NOT IN (
  'admin',
  'system'
  )
AND (
  email NOT LIKE '%z%'
  OR email IS NULL
)
ORDER BY username
