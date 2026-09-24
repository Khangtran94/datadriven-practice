def validate_ab_string(s: str) -> bool:
  see_b = False
  for c in s:
    if c == 'b':
      see_b = True
    elif c == 'a' and see_b:
      return False
  return True
