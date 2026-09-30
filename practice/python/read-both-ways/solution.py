


def find_palindromes(tokens):
  total = []

  for x in tokens:
    clean = "".join(c for c in x.lower() if c.isalnum())

    if clean and clean == clean[::-1]:
      total.append(x)

  return total
