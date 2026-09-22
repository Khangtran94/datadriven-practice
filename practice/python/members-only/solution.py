def filter_odd_digits(s: str) -> str:
  return "".join([i for i in s if int(i) % 2 != 0])
