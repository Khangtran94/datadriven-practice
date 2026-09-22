def compare_tag_lists(a, b):
  return {"both":list(set(a).intersection(set(b))), 'only_a':list(set(a) - set(b)), 'only_b':list(set(b) - set(a))}
