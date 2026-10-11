def parse_address(address):
  text = address.split(',')
  street = text[0].strip()
  city = text[1].strip()
  state, zip_code = text[2].split()[0].strip(), text[2].split()[1].strip()
  return {'zip':zip_code, 'city':city, 'state':state, 'street':street}
