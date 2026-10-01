def safe_divide_batch(pairs: list) -> list:
  # pairs: list of [numerator, denominator]
  # Return float result, 'division by zero', or 'invalid input'
  total = []
  for x,y in pairs:
    if y == 0:
      total.append('division by zero')
    elif not isinstance(x,(int,float)) or not isinstance(y,(int,float)):
      total.append('invalid input')
    else:
      total.append(float(x/y))
  return total
