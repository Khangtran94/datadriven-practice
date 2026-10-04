import json
import re
from datetime import datetime, timezone, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

#### define 
QUALITY_MAP = {
    "a": "actual",
    "actual": "actual",
    "sub": "estimated",
    "e": "estimated",
    "est": "estimated",
    "estimated": "estimated",
    "estimate": "estimated",
    "substituted": "estimated",
}
METER_RE = re.compile(r"M-\d{7}")
RANK = {"actual": 2, "estimated": 1, None: 0}
ALIASES = {
    "meter_id": ["meter_id", "meterid", "meter", 'id',"mid", "msn"],
    "interval_end": ["interval_end", "intervalend", "end", "ts", "timestamp", "period_end",'event_time'],
    "kwh": ["kwh", "usage_kwh", "usage", "energy_kwh", "energy",
            "wh", "usage_wh", "energy_wh", "mwh", "usage_mwh", "energy_mwh"],
    "register": ["register", "register_kwh", "reg", "total_kwh", "cumulative",
                 "register_wh", "reg_wh", "total_wh", "register_mwh", "reg_mwh", "total_mwh"],
    "quality": ["quality", "q", "read_type", "status",'flag'],
}

### Factor for unit in energy
UNIT_FACTOR = {"wh": Decimal("0.001"), "kwh": Decimal("1"), "mwh": Decimal("1000")}
NULL_STRINGS = {"", "null", "none", "n/a", "na", "nan", "-", "--"}
LOOKUP = {re.sub(r"[^a-z0-9]", "", a): c for c, al in ALIASES.items() for a in al}
SEQ_KEYS = ("_seq", "seq", "received_at")
VAL_RE = re.compile(r"([-+]?[\d.,]*\d(?:[eE][-+]?\d+)?)\s*([A-Za-z]*)")

### Normalize key column
def _normalize_key_name(k):
    """Collapse a raw key to a bare lowercase alnum string so
    'Title_ID', 'title-id', 'titleId' all compare equal."""
    return re.sub(r"[^a-z0-9]", "", str(k).lower())

def norm_unit(u):
    if not isinstance(u, str):
        return None
    u = re.sub(r"[^a-z]", "", u.lower())
    return u if u in UNIT_FACTOR else None

def key_unit(k):
    nk = _normalize_key_name(k)
    if nk.endswith("mwh"):
        return "mwh"
    if nk.endswith("kwh"):
        return "kwh"
    if nk.endswith("wh"):
        return "wh"
    return None

### Check json format first:
def extract_json(raw):
    if not isinstance(raw,str):
        return None
    raw = raw.strip()
    try: 
        record = json.loads(raw)
        if isinstance(record, dict):
            return record
    except json.JSONDecodeError:
        pass
    
    ### Recover JSON from surronding text:
    start = raw.find('{')
    end = raw.rfind('}')
    if start == -1 or end <= start:
        return None
    try:
        record = json.loads(raw[start:end+1])
        if isinstance(record, dict):
            return record
    except json.JSONDecodeError:
        return None
    return None

### Flatten if need:
def flatten(obj, depth=0):
    """Pull fields out of one or two levels of sub-objects."""
    flat = {}

    for k, v in obj.items():
        if isinstance(v, dict) and depth < 2:
            for k2, v2 in flatten(v, depth + 1).items():
                flat.setdefault(k2, v2)
        else:
            flat.setdefault(k, v)

    return flat

### Check lookup and convert to the format
def canonical(obj):
    out, units, extra = {}, {}, {}
    for k, v in flatten(obj).items():
        c = LOOKUP.get(_normalize_key_name(k))
        if c is not None:
            if out.get(c) is None:
                out[c] = v
                if c in ("kwh", "register"):
                    units[c] = key_unit(k)
        elif k in SEQ_KEYS:
            extra[k] = v
    return out, units, extra

### Format column:
def norm_meter(v):
    if not isinstance(v, str):
        return None
    v = v.strip().upper()
    return v if METER_RE.fullmatch(v) else None

def norm_time(time_check):
    if time_check is None or isinstance(time_check, bool):
        return None
    # Unix timestamp
    if isinstance(time_check, (int, float)):
        try:
            num = float(time_check)
            # Treat large timestamps as milliseconds
            if num > 1e11:
                num /= 1000
            dt = datetime.fromtimestamp(num, tz=timezone.utc)
            return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        except (OSError, ValueError, OverflowError):
            return None
    if not isinstance(time_check, str):
        return None
    time_check = time_check.strip()

    if not time_check:
        return None
    # Numeric string -> Unix timestamp
    try:
        num = float(time_check)
        # Treat large timestamps as milliseconds
        if num > 1e11:
            num /= 1000
        dt = datetime.fromtimestamp(num, tz=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except (ValueError, OSError, OverflowError):
        pass
    # ISO 8601
    try:
        dt = datetime.fromisoformat(
            time_check.replace("Z", "+00:00")
        )
        # No timezone -> assume UTC
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        else:
            dt = dt.astimezone(timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return None

### unit energy
def norm_dec(v, field_unit=None):
    """Normalize energy value to Decimal kWh, 3 decimal places."""
    if v is None or isinstance(v, bool):
        return None
    unit = None
    if isinstance(v, str):
        s = v.strip()
        if s.lower() in NULL_STRINGS:
            return None
        m = VAL_RE.fullmatch(s)
        if not m:
            return None
        text, suffix = m.group(1), m.group(2)
        if suffix:
            unit = norm_unit(suffix)
            if unit is None:
                return None
        v = text
    elif not isinstance(v, (int, float)):
        return None
    unit = unit or norm_unit(field_unit) or "kwh"
    try:
        d = Decimal(str(v))
    except InvalidOperation:
        return None
    if not d.is_finite() or d < 0:
        return None
    return (
        d * UNIT_FACTOR[unit]
    ).quantize(
        Decimal("0.001"),
        rounding=ROUND_HALF_UP
    )

### Quality
def norm_quality(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        v = str(v)
    if not isinstance(v, str):
        return None
    return QUALITY_MAP.get(v.strip().lower())

### Bucket
def bucket_interval(ts):
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None
    base = dt.replace(minute=0, second=0, microsecond=0)
    off = dt - base
    if off == timedelta(0):
        b = base
    elif off <= timedelta(minutes=30):
        b = base + timedelta(minutes=30)
    else:
        b = base + timedelta(hours=1)
    return b

### Clean + check quality inside already
def clean(rec, units=None):
    if not isinstance(rec, dict):
        return None
    units = units or {}
    meter = norm_meter(rec.get("meter_id"))
    if meter is None:
        return None
    interval = norm_time(rec.get("interval_end"))
    if interval is None:
        return None
    return {
        "meter_id": meter,
        "interval_end": interval,
        "usage_kwh": norm_dec(
            rec.get("kwh"),
            field_unit=units.get("kwh"),
        ),
        "register_kwh": norm_dec(
            rec.get("register"),
            field_unit=units.get("register"),
        ),
        "quality": norm_quality(rec.get("quality")),
    }


#### Handler:
SNAP = True           
EMIT_UPDATES = False   

def find_pos(lst, key):
    lo, hi = 0, len(lst)
    while lo < hi:
        mid = (lo + hi) // 2
        if lst[mid][0] < key:
            lo = mid + 1
        else:
            hi = mid
    return lo

class Handler:
    def __init__(self):
        self.reads = {}   # (meter, bucket) -> {interval_end: row}
        self.regs = {}    # meter -> [(bucket, register)] đã sort
        self.sent = {}    # (meter, bucket) -> tuple giá trị đã emit

    def _dedup(self, m, b, row):
        reads = self.reads.setdefault((m, b), {})
        ts = row["interval_end"]
        old = reads.get(ts)
        if old is not None and RANK[row["quality"]] <= RANK[old["quality"]]:
            return False
        reads[ts] = row
        return True

    def _bucket(self, ts):
        if not SNAP:
            return ts
        b = bucket_interval(ts)
        return b.strftime("%Y-%m-%dT%H:%M:%SZ") if b else None

    def _merge(self, m, b):
        reads = self.reads[(m, b)]
        rs = [reads[t] for t in sorted(reads)]
        usage = next((r["usage_kwh"] for r in reversed(rs) if r["usage_kwh"] is not None), None)
        reg = next((r["register_kwh"] for r in reversed(rs) if r["register_kwh"] is not None), None)
        qs = {r["quality"] for r in rs}
        quality = "actual" if "actual" in qs else ("estimated" if "estimated" in qs else None)
        return {"meter_id": m, "interval_end": b,
                "usage_kwh": usage, "register_kwh": reg, "quality": quality}

    def _usage(self, m, b, row):
        lst = self.regs.setdefault(m, [])
        i = find_pos(lst, b)
        reg = row["register_kwh"]
        if row["usage_kwh"] is None and reg is not None and i > 0:
            d = reg - lst[i - 1][1]
            if d >= 0:
                row["usage_kwh"] = d
        if reg is not None:
            if i < len(lst) and lst[i][0] == b:
                lst[i] = (b, reg)
            else:
                lst.insert(i, (b, reg))
        return row

    def process(self, raw):
        try:
            payload = extract_json(raw)
            if payload is None:
                return []
            normalized, units, _ = canonical(payload)
            row = clean(normalized, units)
            if row is None:
                return []

            m = row["meter_id"]
            b = self._bucket(row["interval_end"])
            if b is None:
                return []
            if not self._dedup(m, b, row):
                return []

            out = self._usage(m, b, self._merge(m, b))
            sig = (out["usage_kwh"], out["register_kwh"], out["quality"])
            if (m, b) in self.sent and (not EMIT_UPDATES or self.sent[(m, b)] == sig):
                return []
            self.sent[(m, b)] = sig
            return [out]
        except (TypeError, ValueError, KeyError, AttributeError, OverflowError, OSError):
            return []

    def finalize(self):
        return []
