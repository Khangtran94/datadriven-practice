def validate_ab_string(s: str) -> bool:
  for i,c in enumerate(s):
    if i+1 < len(s):
      if s[i+1] == 'a' and s[i] == 'b':
        return False
  return True
