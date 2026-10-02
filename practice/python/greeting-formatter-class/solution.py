class MessageFormatter:
  def sort_by_case(self, text):
    lower = []
    upper = []
    other = []
    for t in text:
      if t.islower():
        lower.append(t)
      elif t.isupper():
        upper.append(t)
      else:
        other.append(t)
    return ''.join(lower + upper + other)
        
def sort_by_case(text):
  formatter = MessageFormatter()
  return formatter.sort_by_case(text)
    
