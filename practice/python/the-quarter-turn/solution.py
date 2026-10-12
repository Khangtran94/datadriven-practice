def rotate_90_clockwise(matrix: list) -> list:
  if not matrix:
    return []
  total = []
  for i in range(len(matrix[0])):
    total.append([m[i] for m in matrix][::-1])
  return total
