def mismatched_words(sentence_a: str, sentence_b: str) -> list[str]:
  sa = set(sentence_a.split())
  sb = set(sentence_b.split())
  total = [w for w in sa if w not in sb]
  total += [w for w in sb if w not in sa]
  return total
