def inverted_triangle(n: int) -> list[str]:
  total = []
  while n > 0:
    total.append('*'*n)
    n -= 1
  return total
