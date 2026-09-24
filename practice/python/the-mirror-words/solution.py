def reverse_each_word(sentence):
  new = sentence.split(' ')
  return ' '.join([n[::-1] for n in new])
