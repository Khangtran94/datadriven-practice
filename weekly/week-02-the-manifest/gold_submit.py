import json
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from functools import lru_cache
 
 
_MISSING = object()
_CONFLICT = object()
_UTC = timezone.utc
_EPOCH = datetime(1970, 1, 1, tzinfo=_UTC)
_MILLI = Decimal('0.001')
_HEIGHTS = {240, 360, 480, 720, 1080, 2160}
_WIDTHS = {426: 240, 427: 240, 640: 360, 854: 480, 853: 480,
           1280: 720, 1920: 1080, 3840: 2160}
_TITLE = re.compile(r'T-[0-9]{7}\Z')
_NUMBER_UNIT = re.compile(r'([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*(.*?)\Z')
_NEXT_FIELD = re.compile(r'\s+(?:["\'][^"\'\r\n]+["\']|[A-Za-z_][\w.-]*)\s*[:=]')
_KEY = re.compile(r'[^a-z0-9]')
_NULLS = {'', 'null', 'none', 'nil', 'nan', 'nat', 'n/a', 'na', 'unknown',
          'undefined', '-', '--', 'not available'}
_DECODER = json.JSONDecoder(strict=False)
 
 
@lru_cache(maxsize=512)
def _key(value):
    return _KEY.sub('', value.strip().lower())
 
 
class _LooseJSON:
    """Slow path for logger syntax; never executes source text."""
 
    def __init__(self, text):
        self.text = text
        self.i = 0
        self.n = len(text)
 
    def space(self):
        while self.i < self.n:
            if self.text[self.i].isspace():
                self.i += 1
            elif self.text.startswith('//', self.i):
                end = self.text.find('\n', self.i)
                self.i = self.n if end < 0 else end + 1
            elif self.text.startswith('/*', self.i):
                end = self.text.find('*/', self.i + 2)
                self.i = self.n if end < 0 else end + 2
            else:
                break
 
    def quoted(self):
        quote = self.text[self.i]
        self.i += 1
        out = []
        while self.i < self.n:
            c = self.text[self.i]
            self.i += 1
            if c == quote:
                end = self.i
                while end < self.n and self.text[end].isspace():
                    end += 1
                # Loggers sometimes leave quotes inside a string unescaped.
                if end == self.n or self.text[end] in ':,;}]= ' or _NEXT_FIELD.match(self.text, self.i):
                    return ''.join(out)
                out.append(c)
                continue
            if c == '\\' and self.i < self.n:
                c = self.text[self.i]
                self.i += 1
                if c == 'u' and self.i + 4 <= self.n:
                    chunk = self.text[self.i:self.i + 4]
                    try:
                        out.append(chr(int(chunk, 16)))
                        self.i += 4
                        continue
                    except ValueError:
                        pass
                out.append({'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f'}.get(c, c))
            else:
                out.append(c)
        # A truncated quoted value is not recoverable.
        raise ValueError('Unterminated string')
 
    def value(self, depth=0):
        if depth > 16:
            raise ValueError('Nesting too deep')
        self.space()
        if self.i >= self.n:
            raise ValueError('Missing value')
        c = self.text[self.i]
        if c in '\"\'':
            return self.quoted()
        if c == '{':
            self.i += 1
            obj = {}
            while True:
                self.space()
                if self.i >= self.n:
                    return obj  # Only complete fields of a truncated object.
                if self.text[self.i] == '}':
                    self.i += 1
                    return obj
                if self.text[self.i] in ',;':
                    self.i += 1
                    continue
                if self.text[self.i] in '\"\'':
                    name = self.quoted()
                else:
                    start = self.i
                    while self.i < self.n and self.text[self.i] not in ':=,{}\r\n':
                        self.i += 1
                    name = self.text[start:self.i].strip()
                self.space()
                if not name or self.i >= self.n or self.text[self.i] not in ':=':
                    raise ValueError('Missing field separator')
                self.i += 1
                try:
                    obj[name] = self.value(depth + 1)
                except ValueError:
                    if self.i >= self.n:
                        return obj
                    raise
        if c == '[':
            self.i += 1
            result = []
            while True:
                self.space()
                if self.i >= self.n:
                    return result
                if self.text[self.i] == ']':
                    self.i += 1
                    return result
                if self.text[self.i] == ',':
                    self.i += 1
                else:
                    result.append(self.value(depth + 1))
        start = self.i
        while self.i < self.n and self.text[self.i] not in ',;}]\r\n':
            if self.text[self.i].isspace() and _NEXT_FIELD.match(self.text, self.i):
                break
            self.i += 1
        token = self.text[start:self.i].strip()
        if not token:
            raise ValueError('Empty token')
        lowered = token.lower()
        if lowered in _NULLS or lowered in {'infinity', '-infinity', 'inf', '-inf'}:
            return None
        if lowered in {'true', 'false'}:
            return lowered == 'true'
        # Retaining scalar text also preserves decimals exactly.
        return token
 
 
def _parse(raw, depth=0):
    if depth > 3 or not isinstance(raw, str):
        return None
    text = raw.strip('\ufeff \t\r\n\x00')
    if not text:
        return None
    try:
        value = json.loads(text, strict=False)
    except (ValueError, RecursionError):
        value = _MISSING
        # A logger may add a timestamp/level or a suffix around a JSON object.
        starts = [p for p in (text.find('{'), text.find('[')) if p >= 0]
        for start in sorted(starts):
            try:
                value, unused = _DECODER.raw_decode(text, start)
                if isinstance(value, (dict, list)):
                    break
            except (ValueError, RecursionError):
                continue
        if value is _MISSING:
            for start in sorted(starts):
                try:
                    value = _LooseJSON(text[start:]).value()
                    if isinstance(value, (dict, list)):
                        break
                except (ValueError, RecursionError):
                    continue
        if value is _MISSING:
            return None
    if isinstance(value, str):
        return _parse(value, depth + 1)
    return value if isinstance(value, (dict, list)) else None
 
 
_TITLE_KEYS = ('titleid', 'assetid', 'contentid', 'videoid', 'title', 'asset', 'id')
_RENDITION_KEYS = ('variant', 'rendition', 'representation', 'quality', 'resolution',
                   'profilename', 'profile', 'renditionname', 'variantname', 'label')
_CODEC_KEYS = ('codec', 'videocodec', 'codecname', 'codecid', 'vcodec', 'encoding', 'fourcc')
_RATE_KEYS = ('bitratekbps', 'bitrate', 'videobitrate', 'bandwidth', 'bitratebps',
              'bitratembps', 'bitratebitspersecond', 'ratekbps', 'ratebps', 'rate')
_DURATION_KEYS = ('durations', 'durationseconds', 'durationsec', 'duration',
                  'durationms', 'durationmillis', 'durationmilliseconds',
                  'durationus', 'runtime', 'runtimeseconds', 'lengthseconds')
_TIME_KEYS = ('packagedat', 'packaged', 'packagedtimestamp', 'packagedtime',
              'packagedatms', 'packagedms', 'encodedat', 'encodingtime',
              'completedat', 'finishedat', 'createdat')
_JOB_KEYS = ('jobid', 'encodingjobid', 'encodejobid', 'job')
_CONTAINERS = ('payload', 'data', 'record', 'message', 'result', 'output',
               'media', 'video', 'encoding', 'attributes', 'metadata', 'meta')
_LISTS = ('outputs', 'renditions', 'variants', 'representations', 'streams', 'records')
 
 
def _pick(rec, names):
    for name in names:
        if name in rec:
            return rec[name], name
    return _MISSING, ''
 
 
def _flatten(rec, depth=0):
    if not isinstance(rec, dict) or depth > 6:
        return {}
    out = {_key(k): v for k, v in rec.items() if isinstance(k, str)}
    for name in _CONTAINERS:
        child = out.get(name)
        if isinstance(child, str) and child.lstrip().startswith(('{', '[')):
            child = _parse(child)
        if isinstance(child, dict):
            nested = _flatten(child, depth + 1)
            del out[name]
            for k, v in nested.items():
                out.setdefault(k, v)
    for name in ('title', 'asset', 'content'):
        child = out.get(name)
        if isinstance(child, dict):
            child = _flatten(child, depth + 1)
            ident, unused = _pick(child, ('titleid', 'assetid', 'contentid', 'id'))
            if ident is not _MISSING:
                out.setdefault('titleid', ident)
            del out[name]
            for k in _DURATION_KEYS:
                if k in child:
                    out.setdefault(k, child[k])
    job = out.get('job')
    if isinstance(job, dict):
        job = _flatten(job, depth + 1)
        ident, unused = _pick(job, ('jobid', 'id'))
        if ident is not _MISSING:
            out.setdefault('jobid', ident)
        del out['job']
        for k, v in job.items():
            if k != 'id':
                out.setdefault(k, v)
    return out
 
 
def _expand(value, depth=0):
    if depth > 8:
        return
    if isinstance(value, list):
        for item in value:
            yield from _expand(item, depth + 1)
        return
    if not isinstance(value, dict):
        return
    rec = _flatten(value)
    for name in _LISTS:
        items = rec.get(name)
        if isinstance(items, (list, dict)):
            parent = {k: v for k, v in rec.items() if k not in _LISTS}
            pairs = items.items() if isinstance(items, dict) else ((None, item) for item in items)
            for label, child in pairs:
                if isinstance(child, dict):
                    merged = dict(parent)
                    merged.update(_flatten(child))
                    if label is not None and not any(k in merged for k in _RENDITION_KEYS):
                        merged['variant'] = label
                    yield from _expand(merged, depth + 1)
            return
    yield rec
 
 
def _title(value):
    if not isinstance(value, str):
        return None
    value = value.strip().upper()
    return value if _TITLE.fullmatch(value) else None
 
 
@lru_cache(maxsize=512)
def _rendition_text(value):
    value = value.strip().lower().replace('×', 'x')
    compact = re.sub(r'[\s_-]+', '', value)
    aliases = {'4k': '2160p', 'uhd': '2160p', 'uhd4k': '2160p',
               '4kuhd': '2160p', 'fullhd': '1080p', 'fhd': '1080p', 'hd': '720p'}
    if compact in aliases:
        return aliases[compact]
    # Width wins for dimensions, including letterboxed encodes (1920x800).
    dimensions = re.fullmatch(r'(\d{3,4})\s*x\s*\d{2,4}(?:\s*[pi])?', value)
    if dimensions:
        height = _WIDTHS.get(int(dimensions[1]))
        return str(height) + 'p' if height else None
    match = re.fullmatch(r'(240|360|480|720|1080|2160)(?:p(?:\d+(?:\.\d+)?)?)?', compact)
    if match:
        return match[1] + 'p'
    if compact.isdigit() and int(compact) in _WIDTHS:
        return str(_WIDTHS[int(compact)]) + 'p'
    # Labels such as video_1080p_h264, but never infer from bitrate or codec.
    matches = set(re.findall(r'(?<!\d)(240|360|480|720|1080|2160)p(?!\d)', value))
    if len(matches) == 1:
        return matches.pop() + 'p'
    width = re.fullmatch(r'(?:w(?:idth)?[:=]?)?(\d{3,4})(?:w|wide)?', compact)
    if width and int(width[1]) in _WIDTHS:
        return str(_WIDTHS[int(width[1])]) + 'p'
    return None
 
 
def _rendition(rec):
    value, unused = _pick(rec, _RENDITION_KEYS)
    if isinstance(value, dict):
        nested = _flatten(value)
        for name in ('name', 'label', 'id'):
            if isinstance(nested.get(name), (str, int)):
                found = _rendition_text(str(nested[name]))
                if found:
                    return found
        rec = dict(rec, **nested)
    elif isinstance(value, (str, int)) and not isinstance(value, bool):
        found = _rendition_text(str(value))
        if found:
            return found
    for name in ('width', 'videowidth', 'widthpx'):
        value = rec.get(name)
        if isinstance(value, (str, int)) and not isinstance(value, bool):
            try:
                height = _WIDTHS.get(int(value))
            except ValueError:
                height = None
            if height:
                return str(height) + 'p'
    value = rec.get('height', rec.get('videoheight'))
    if isinstance(value, (str, int)) and not isinstance(value, bool):
        return _rendition_text(str(value)) if str(value).strip().isdigit() and int(value) in _HEIGHTS else None
    return None
 
 
@lru_cache(maxsize=256)
def _codec_text(value):
    value = value.strip().lower()
    compact = re.sub(r'[\s_.-]+', '', value)
    aliases = {'h264': 'h264', 'avc': 'h264', 'avc1': 'h264', 'avc3': 'h264',
               'x264': 'h264', 'libx264': 'h264', 'h265': 'h265', 'hevc': 'h265',
               'hev1': 'h265', 'hvc1': 'h265', 'x265': 'h265', 'libx265': 'h265',
               'av1': 'av1', 'av01': 'av1', 'libaomav1': 'av1', 'libsvtav1': 'av1',
               'svtav1': 'av1', 'vp9': 'vp9', 'vp09': 'vp9', 'libvpxvp9': 'vp9'}
    if compact in aliases:
        return aliases[compact]
    if re.fullmatch(r'(avc1|avc3)\.[0-9a-f]{6}', value):
        return 'h264'
    if re.fullmatch(r'(hev1|hvc1)\.[a-z0-9.]+', value):
        return 'h265'
    if re.fullmatch(r'av01\.[a-z0-9.]+', value):
        return 'av1'
    if re.fullmatch(r'vp09\.[0-9.]+', value):
        return 'vp9'
    return None
 
 
def _codec(value):
    if isinstance(value, dict):
        value, unused = _pick(_flatten(value), ('name', 'codec', 'id'))
    return _codec_text(value) if isinstance(value, str) else None
 
 
def _decimal_unit(value):
    if value is _MISSING or value is None or isinstance(value, bool):
        return None, ''
    if isinstance(value, (int, float, Decimal)):
        number = Decimal(str(value))
        return (number, '') if number.is_finite() else (None, '')
    if not isinstance(value, str) or len(value) > 150:
        return None, ''
    value = value.strip()
    if value.lower() in _NULLS:
        return None, ''
    # Strip grouping only when the complete numeric prefix has valid groups.
    grouped = re.fullmatch(r'([+-]?\d{1,3}(?:[, _\u00a0\u202f]\d{3})+(?:\.\d+)?)\s*([a-zA-Z/µμ]*)', value)
    if grouped:
        value = re.sub(r'[, _\u00a0\u202f]', '', grouped[1]) + grouped[2]
    match = _NUMBER_UNIT.fullmatch(value)
    if not match:
        return None, ''
    try:
        number = Decimal(match[1])
    except InvalidOperation:
        return None, ''
    return (number, match[2]) if number.is_finite() else (None, '')
 
 
def _bitrate(value, name):
    if isinstance(value, dict):
        obj = _flatten(value)
        value = obj.get('value', obj.get('amount'))
        unit = obj.get('unit', obj.get('units', ''))
        if isinstance(unit, str) and isinstance(value, (int, float, str)):
            value = str(value) + ' ' + unit
    number, unit = _decimal_unit(value)
    if number is None or number < 0 or number > Decimal('1e18'):
        return None
    # B/s explicitly means bytes; b/s and bps mean bits.
    bytes_unit = 'B' in unit and ('/s' in unit or unit.endswith('Bps'))
    unit = unit.lower().replace(' ', '').replace('bits', 'bit')
    units = {'kbps': Decimal(1), 'kbit/s': Decimal(1), 'kb/s': Decimal(1),
             'kbits/s': Decimal(1), 'k': Decimal(1), 'kb': Decimal(1),
             'mbps': Decimal(1000), 'mbit/s': Decimal(1000), 'mb/s': Decimal(1000),
             'm': Decimal(1000), 'mb': Decimal(1000),
             'bps': _MILLI, 'bit/s': _MILLI, 'b/s': _MILLI,
             'gbps': Decimal(1000000), 'gbit/s': Decimal(1000000)}
    if unit:
        factor = units.get(unit)
        if factor is None:
            return None
        if bytes_unit:
            factor *= 8
    else:
        factor = (Decimal(1000) if name == 'bitratembps' else
                  _MILLI if name in {'bandwidth', 'bitratebps', 'ratebps', 'bitratebitspersecond'} else Decimal(1))
    number *= factor
    # Whole kbps only: no undocumented rounding or magnitude-based unit guesses.
    return int(number) if number == number.to_integral_value() else None
 
 
def _duration(value, name):
    if isinstance(value, dict):
        obj = _flatten(value)
        amount = obj.get('value', obj.get('amount'))
        unit = obj.get('unit', obj.get('units', ''))
        value = str(amount) + ' ' + unit if isinstance(unit, str) and isinstance(amount, (str, int, float)) else None
    if isinstance(value, str):
        text = value.strip()
        clock = re.fullmatch(r'(?:(\d+):)?(\d{1,2}):(\d{2}(?:\.\d+)?)', text)
        if clock:
            hours, minutes, seconds = clock.groups()
            if int(minutes) >= 60 or Decimal(seconds) >= 60:
                return None
            number = Decimal(hours or 0) * 3600 + Decimal(minutes) * 60 + Decimal(seconds)
            return format(number.quantize(_MILLI, rounding=ROUND_HALF_UP), '.3f')
        iso = re.fullmatch(r'PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?', text, re.I)
        if iso and any(v is not None for v in iso.groups()):
            number = sum(Decimal(v or 0) * scale for v, scale in zip(iso.groups(), (3600, 60, 1)))
            return format(number.quantize(_MILLI, rounding=ROUND_HALF_UP), '.3f')
    number, unit = _decimal_unit(value)
    if number is None or number < 0 or number > Decimal('1e15'):
        return None
    unit = unit.strip().lower()
    if not unit:
        unit = 'ms' if name in {'durationms', 'durationmillis', 'durationmilliseconds'} else 'us' if name == 'durationus' else 's'
    factors = {'s': Decimal(1), 'sec': Decimal(1), 'secs': Decimal(1), 'second': Decimal(1), 'seconds': Decimal(1),
               'ms': _MILLI, 'millisecond': _MILLI, 'milliseconds': _MILLI,
               'us': Decimal('0.000001'), 'µs': Decimal('0.000001'), 'μs': Decimal('0.000001'),
               'm': Decimal(60), 'min': Decimal(60), 'minutes': Decimal(60),
               'h': Decimal(3600), 'hr': Decimal(3600), 'hours': Decimal(3600)}
    factor = factors.get(unit)
    if factor is None:
        return None
    number *= factor
    return format(number.quantize(_MILLI, rounding=ROUND_HALF_UP), '.3f')
 
 
def _timestamp(value, name=''):
    if value is _MISSING or value is None or isinstance(value, bool):
        return None, None
    if isinstance(value, dict):
        value = value.get('$date', value.get('value'))
    if not isinstance(value, (str, int, float)):
        return None, None
    text = str(value).strip()
    if text.lower() in _NULLS:
        return None, None
    try:
        if re.fullmatch(r'[+-]?\d+(?:\.\d+)?', text):
            number = Decimal(text)
            magnitude = abs(number)
            if name in {'packagedatms', 'packagedms'} or magnitude >= Decimal('1e11') and magnitude < Decimal('1e14'):
                number /= 1000
            elif magnitude >= Decimal('1e17'):
                number /= 1000000000
            elif magnitude >= Decimal('1e14'):
                number /= 1000000
            instant = _EPOCH + timedelta(microseconds=int(number * 1000000))
        else:
            text = re.sub(r'\s+(UTC|GMT)\Z', '+00:00', text, flags=re.I)
            if text.endswith(('z', 'Z')):
                text = text[:-1] + '+00:00'
            # Slash dates are accepted only year-first; 01/02 is ambiguous.
            if re.match(r'^\d{4}/\d{2}/\d{2}', text):
                text = text[:10].replace('/', '-') + text[10:]
            instant = datetime.fromisoformat(text)
            if instant.tzinfo is None:
                instant = instant.replace(tzinfo=_UTC)
            instant = instant.astimezone(_UTC)
        normalized = instant.replace(microsecond=0).isoformat().replace('+00:00', 'Z')
        return normalized, instant
    except (ValueError, TypeError, OverflowError, InvalidOperation):
        return None, None
 
 
def _safe(function, *args):
    # A bad cell must not discard the other valid cells of its record.
    try:
        return function(*args)
    except (ValueError, TypeError, OverflowError, InvalidOperation, RecursionError):
        return None
 
 
def _clean(rec):
    title = None
    for name in _TITLE_KEYS:
        title = _title(rec.get(name))
        if title:
            break
    rendition = _safe(_rendition, rec)
    if title is None or rendition is None:
        return None
    codec, unused = _pick(rec, _CODEC_KEYS)
    rate, rate_name = _pick(rec, _RATE_KEYS)
    duration, duration_name = _pick(rec, _DURATION_KEYS)
    packaged, time_name = _pick(rec, _TIME_KEYS)
    stamp, instant = _timestamp(packaged, time_name)
    row = (title, rendition, _safe(_codec, codec), _safe(_bitrate, rate, rate_name),
           _safe(_duration, duration, duration_name), stamp)
    return row, instant
 
 
def _job_id(rec):
    value, unused = _pick(rec, _JOB_KEYS)
    if isinstance(value, (str, int)) and not isinstance(value, bool):
        return str(value).strip() or None
    return None
 
 
def _closed(rec):
    for key in ('event', 'eventtype', 'type', 'kind', 'status', 'state', 'action'):
        value = rec.get(key)
        if isinstance(value, str):
            name = _key(value)
            if name in {'close', 'closed', 'complete', 'completed', 'done', 'finished', 'end',
                        'jobclose', 'jobclosed', 'jobcomplete', 'jobcompleted', 'jobdone',
                        'jobfinished', 'jobend', 'encodecomplete', 'encodingcomplete'}:
                return True
    return False
 
 
def _inherit(rec, context):
    result = dict(rec)
    # Alias-aware inheritance: a present null is deliberately NOT backfilled.
    groups = (_TITLE_KEYS, _RENDITION_KEYS, _CODEC_KEYS, _RATE_KEYS, _DURATION_KEYS, _TIME_KEYS)
    for names in groups:
        value, unused = _pick(rec, names)
        if names is _TITLE_KEYS and unused == 'id' and not _title(value):
            value = _MISSING
        if value is _MISSING:
            value, key = _pick(context, names)
            if value is not _MISSING:
                result[key] = value
    for name in ('width', 'height', 'videowidth', 'videoheight'):
        if name not in result and name in context:
            result[name] = context[name]
    return result
 
 
class Handler:
    def __init__(self):
        self.held = {}  # (title, rendition) -> (latest instant, compact row)
        self.jobs = {}  # Only unfinished jobs: context + pending outputs.
 
    def _accept(self, rec):
        clean = _clean(rec)
        if clean is None:
            return
        row, instant = clean
        key = row[:2]
        previous = self.held.get(key)
        if previous is None:
            self.held[key] = (instant, row)
            return
        old_instant, old_row = previous
        if instant is not None and (old_instant is None or instant > old_instant):
            self.held[key] = (instant, row)
        elif instant == old_instant:
            # Same package/replay: preserve known cells, fill holes only.
            # Conflicting values at the same instant are not safe to guess.
            cells = []
            for old, new in zip(old_row, row):
                cells.append(old if old is _CONFLICT or new is None or old == new
                             else new if old is None else _CONFLICT)
            self.held[key] = (instant, tuple(cells))
 
    def _process_record(self, rec):
        job = _job_id(rec)
        rendition = _safe(_rendition, rec)
        if job is None:
            if rendition:
                self._accept(rec)
            return
        # Complete outputs cannot gain cells from the close record. Store just
        # their normalized winner, avoiding an extra full record per job.
        complete = (rendition and any(_title(rec.get(k)) for k in _TITLE_KEYS)
                    and all(_pick(rec, names)[0] is not _MISSING
                            for names in (_CODEC_KEYS, _RATE_KEYS, _DURATION_KEYS, _TIME_KEYS)))
        if complete:
            self._accept(rec)
            if not _closed(rec) or job not in self.jobs:
                return
        context, pending = self.jobs.setdefault(job, ({}, []))
        closing = _closed(rec)
        if rendition and not complete:
            pending.append(rec)
        elif not rendition:
            # Context records are not output rows, even when they carry a title.
            context.update(rec)
        if closing:
            for output in pending:
                self._accept(_inherit(output, context))
            del self.jobs[job]
 
    def process(self, raw: str) -> list[dict]:
        try:
            value = _parse(raw)
            for rec in _expand(value):
                try:
                    self._process_record(rec)
                except (ValueError, TypeError, OverflowError, InvalidOperation, RecursionError):
                    continue
        except (ValueError, TypeError, OverflowError, InvalidOperation, RecursionError):
            pass
        # A job close settles its context, not future encodes of the same key.
        return []
 
    def finalize(self) -> list[dict]:
        for context, pending in self.jobs.values():
            for rec in pending:
                try:
                    self._accept(_inherit(rec, context))
                except (ValueError, TypeError, OverflowError, InvalidOperation, RecursionError):
                    continue
        self.jobs.clear()
        rows = []
        # Drop compact state as result dictionaries are allocated; preserve
        # first-seen key order without retaining both complete representations.
        for key in list(self.held):
            instant, row = self.held.pop(key)
            rows.append(dict(zip(('title_id', 'rendition', 'codec', 'bitrate_kbps',
                                  'duration_s', 'packaged_at'),
                                 (None if cell is _CONFLICT else cell for cell in row))))
