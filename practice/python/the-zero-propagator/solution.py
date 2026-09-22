def set_zeroes(matrix: list) -> list:
  find = [(i,j) for i,row in enumerate(matrix) for j,v in enumerate(row) if v == 0]
  for i, j in find:
    matrix[i] = [0] * len(matrix[i])
    for row in matrix:
      row[j] = 0
  return matrix
