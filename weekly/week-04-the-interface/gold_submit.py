import json
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
 
 
_TEST_NAMES = ('glucose', 'sodium', 'potassium', 'creatinine', 'hemoglobin', 'wbc')
_TEST_CODES = {'2345-7': 0, 'GLU': 0, '2951-2': 1, 'NA': 1,
               '2823-3': 2, 'K': 2, '2160-0': 3, 'CREAT': 3,
               '718-7': 4, 'HGB': 4, '6690-2': 5, 'WBC': 5}
_UNITS = (None, 'mg/dL', 'mmol/L', 'g/dL', '10*3/uL')
_UNIT_CODES = {'mg/dl': 1, 'mmol/l': 2, 'meq/l': 2, 'g/dl': 3,
               '10*3/ul': 4, '10^3/ul': 4, 'k/ul': 4}
_STATUSES = (None, 'preliminary', None, 'final', 'corrected', 'final')
_STATUS_CODES = {'P': 1, 'W': 2, 'F': 3, 'C': 4, 'U': 5}
_RANK = (0, 1, 2, 3, 4, 3)
_NONE = -(1 << 63)
_NO_PATIENT = (1 << 32) - 1
_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
_TS = re.compile(r'^(\d{12}|\d{14})(?:\.(\d{1,6}))?(Z|[+-]\d{4}|[+-]\d{2}:\d{2})?$')
_NUMBER = re.compile(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$')
_GROUPED = re.compile(r'^[+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?$')
_MR = re.compile(r'^[0-9]{8}$')
_SEGMENTS = re.compile(r'[\r\n]+')
_LOG_ESCAPE = re.compile(r'\\+(?:u([0-9a-fA-F]{4})|x([0-9a-fA-F]{2})|([rn]))')
_MESSAGE_KEY = re.compile(r'["\']message["\']\s*:\s*(["\'])')
try:
    _EAST = ZoneInfo('America/New_York')
    _CENTRAL = ZoneInfo('America/Chicago')
except ZoneInfoNotFoundError:
    # US rules since 2007; timestamps outside this period need an explicit offset.
    _EAST = _CENTRAL = None
 
 
def _log_unescape(match):
    if match[1] or match[2]:
        n = int(match[1] or match[2], 16)
        return chr(n) if n else ''
    return '\r' if match[3] == 'r' else '\n'
 
 
def _quoted_prefix(raw, start, quote):
    """Recover only the available characters of a logger's quoted message."""
    out = []
    i = start
    while i < len(raw):
        char = raw[i]
        if char == quote:
            return ''.join(out), False
        if char != '\\':
            out.append(char)
            i += 1
            continue
        i += 1
        if i == len(raw):
            return ''.join(out), True
        char = raw[i]
        short = {'r': '\r', 'n': '\n', 't': '\t', 'b': '\b', 'f': '\f',
                 '"': '"', "'": "'", '\\': '\\', '/': '/'}
        if char in short:
            out.append(short[char])
            i += 1
        elif char in ('u', 'x'):
            size = 4 if char == 'u' else 2
            digits = raw[i + 1:i + 1 + size]
            if len(digits) < size:
                return ''.join(out), True
            try:
                out.append(chr(int(digits, 16)))
                i += size + 1
            except ValueError:
                out.append('\\' + char)
                i += 1
        else:
            # A hand-built logger may leave the HL7 escape backslash unescaped.
            out.append('\\' + char)
            i += 1
    return ''.join(out), True
 
 
def _message(raw):
    if not isinstance(raw, str):
        return None, False
    current = raw.strip('\ufeff \t\r\n')
    for _ in range(3):
        try:
            obj = json.loads(current)
        except (ValueError, TypeError, RecursionError):
            if current.startswith('MSH'):
                return current, False
            match = _MESSAGE_KEY.search(current)
            if match:
                return _quoted_prefix(current, match.end(), match[1])
            return None, False
        if isinstance(obj, dict):
            msg = obj.get('message')
            if isinstance(msg, str):
                if msg.lstrip().startswith('{'):
                    current = msg
                    continue
                # Some engines serialize the message as a JSON string twice.
                for _ in range(2):
                    if not msg.startswith('"'):
                        break
                    try:
                        inner = json.loads(msg)
                    except (ValueError, TypeError):
                        break
                    if not isinstance(inner, str):
                        break
                    msg = inner
                return msg, False
            return None, False
        if not isinstance(obj, str):
            return None, False
        current = obj
    return None, False
 
 
def _decode(text, chars):
    """Decode HL7 escapes AFTER separating fields and components."""
    if not text or text == '""':
        return ''
    escape = chars[2]
    if escape not in text:
        return text.strip()
    codes = {'F': chars[4], 'S': chars[0], 'R': chars[1], 'E': escape, 'T': chars[3],
             'H': '', 'N': ''}
    parts = text.split(escape)
    out = [parts[0]]
    for i in range(1, len(parts), 2):
        token = parts[i]
        if i + 1 == len(parts):
            return ''  # An unfinished escape cannot be used as an identifier.
        if token in codes:
            out.append(codes[token])
        elif token.startswith('X'):
            try:
                out.append(bytes.fromhex(token[1:]).decode('utf-8'))
            except (ValueError, UnicodeError):
                return ''
        else:
            return ''
        out.append(parts[i + 1])
    return ''.join(out).strip()
 
 
def _field(fields, index):
    return fields[index] if index < len(fields) else ''
 
 
def _ids(field, chars, legacy=False):
    answer = set()
    for rep in field.split(chars[1]):
        cx = rep.split(chars[0])
        number = _decode(cx[0], chars)
        if not _MR.fullmatch(number):
            continue
        authority = _decode(_field(cx, 3).split(chars[3])[0], chars).upper()
        kind = _decode(_field(cx, 4), chars).upper()
        if (authority == 'HOSP' and kind == 'MR') or (legacy and len(cx) == 1):
            try:
                answer.add(int(number))
            except ValueError:
                continue
    return answer
 
 
def _patient(pid, chars, hospital):
    for index in (3, 2):
        values = _ids(_field(pid, index), chars, legacy=(index == 2 and hospital))
        if len(values) == 1:
            return next(iter(values))
        if len(values) > 1:
            return _NO_PATIENT
    return _NO_PATIENT
 
 
def _us_offset(naive, central):
    year = naive.year
    if year < 2007:
        return None
    march = datetime(year, 3, 1)
    november = datetime(year, 11, 1)
    spring = march + timedelta(days=(6 - march.weekday()) % 7 + 7, hours=2)
    autumn = november + timedelta(days=(6 - november.weekday()) % 7, hours=1)
    if spring <= naive < spring + timedelta(hours=1):
        return None
    if autumn <= naive < autumn + timedelta(hours=1):
        return None
    return -(6 if central else 5) + (spring < naive < autumn)
 
 
def _time(text, central):
    text = text.strip().split('^')[0]
    match = _TS.fullmatch(text)
    try:
        if match:
            digits, fraction, offset = match.groups()
            digits = digits.ljust(14, '0')
            naive = datetime(int(digits[:4]), int(digits[4:6]), int(digits[6:8]),
                             int(digits[8:10]), int(digits[10:12]), int(digits[12:14]),
                             int((fraction or '').ljust(6, '0')))
            if offset:
                if offset == 'Z':
                    aware = naive.replace(tzinfo=timezone.utc)
                else:
                    clean = offset.replace(':', '')
                    hours, minutes = int(clean[1:3]), int(clean[3:5])
                    if hours > 23 or minutes > 59:
                        return _NONE
                    delta = timedelta(hours=hours, minutes=minutes)
                    aware = naive.replace(tzinfo=timezone(delta if clean[0] == '+' else -delta))
            else:
                aware = None
        else:
            # A few interfaces use ISO timestamps in the TS field.
            naive = datetime.fromisoformat(text.replace('Z', '+00:00'))
            aware = naive if naive.tzinfo is not None else None
        if aware is None:
            if central is None:
                return _NONE
            zone = _CENTRAL if central else _EAST
            if zone is None:
                offset = _us_offset(naive, central)
                if offset is None:
                    return _NONE
                aware = naive.replace(tzinfo=timezone(timedelta(hours=offset)))
            else:
                a = naive.replace(tzinfo=zone, fold=0)
                b = naive.replace(tzinfo=zone, fold=1)
                # Missing and repeated local hours have no single UTC instant.
                if a.utcoffset() != b.utcoffset():
                    return _NONE
                aware = a
        delta = aware.astimezone(timezone.utc) - _EPOCH
        return (delta.days * 86400 + delta.seconds) * 1000000 + delta.microseconds
    except (ValueError, OverflowError, TypeError):
        return _NONE
 
 
def _value(text, kind, chars):
    kind = kind.strip().upper()
    if kind == 'SN':
        parts = text.split(chars[0])
        if len(parts) < 2 or _decode(parts[0], chars) not in ('', '='):
            return _NONE
        if any(_decode(x, chars) for x in parts[2:]):
            return _NONE
        text = parts[1]
    elif kind not in ('NM', 'ST', ''):
        return _NONE
    text = _decode(text, chars).replace('\u2212', '-')
    if _GROUPED.fullmatch(text):
        text = text.replace(',', '')
    if len(text) > 80 or not _NUMBER.fullmatch(text):
        return _NONE
    try:
        number = Decimal(text)
        if not number.is_finite() or number.adjusted() > 15:
            return _NONE
        return int(number.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP) * 100)
    except (InvalidOperation, ValueError, OverflowError):
        return _NONE
 
 
def _unit(text, chars):
    # Bench '10^3/uL' is a whole unit, not code='10', description='3/uL'.
    decoded = _decode(text, chars).replace('\u00b5', 'u').replace('\u03bc', 'u')
    simple = decoded.replace(' ', '').lower()
    if simple in _UNIT_CODES:
        return _UNIT_CODES[simple]
    if simple.startswith('10^3/ul' + chars[0]):
        return 4
    code = _decode(text.split(chars[0])[0], chars)
    return _UNIT_CODES.get(code.replace(' ', '').lower(), 0)
 
 
def _test(text, chars):
    parts = text.split(chars[0])
    for start in (0, 3):
        code = _decode(_field(parts, start), chars).upper()
        system = _decode(_field(parts, start + 2), chars).upper()
        if code in _TEST_CODES and system in ('', 'LN', 'LOINC', 'L', 'LOCAL'):
            return _TEST_CODES[code]
    return None
