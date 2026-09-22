def extract_diagonal(matrix: list) -> list:
  total = []
  for i in range(len(matrix)):
    total.append(matrix[i][i])
  return total
