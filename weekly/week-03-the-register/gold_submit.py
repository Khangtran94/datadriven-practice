import html
import json
import math
import re
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_EVEN
 
NULL_SPELLINGS = {
    "", "null", "none", "n/a", "na", "nil", "undefined", "missing", "-", "--",
    "nan", "nat", "unknown", "n.a.", "n.a", "void", "empty", "nulo", "nichts",
    "nothing", "<na>", "<null>", "#n/a", "na", "none.", "null.", "unbekannt",
}
 
ACTUAL = {
    "a", "actual", "act", "measured", "raw", "real",
    "actualread", "actual_read", "verified",
}
ESTIMATED = {
    "e", "estimated", "est", "estimate", "sub", "substituted", "substitute",
    "subst", "interpolated", "filled", "imputed", "reconstructed", "synth",
    "synthetic", "modeled", "modelled", "replacement", "replaced",
}
 
BOOKKEEPING = {
    "collector", "receivedat", "received_at", "ingestedat", "ingested_at",
    "queuedat", "queued_at", "processedat", "processed_at", "seq", "_seq",
    "batch", "_batch", "exportbatch", "_export_batch", "source", "topic",
    "partition", "offset", "messageid", "message_id", "packager",
    "collectedat", "collected_at", "createdat", "created_at",
}
 
METER_KEYS = [
    "meter_id", "meterid", "meter", "mtr_id", "mtrid", "mtr", "serial",
    "serialnumber", "serialno", "serial_number", "endpointid", "endpoint_id",
    "endpoint", "deviceid", "device_id", "device", "meterno", "meter_no",
    "meternumber", "meter_number", "esiid", "esi_id", "esi", "nmi",
    "id_medidor", "idmedidor", "medidor", "id_compteur", "idcompteur",
    "compteur", "zaehler_id", "zaehlerid", "zaehler", "zahler_id",
    "contatore", "metername", "meter_name", "assetid", "asset_id",
    "meter_serial", "meterserial", "msn", "mpan", "mprn", "id_meter",
    "idmeter", "meter_code", "metercode",
]
 
END_KEYS = [
    "interval_end", "intervalend", "interval_end_utc", "intervalendutc",
    "end_time", "endtime", "end_ts", "endts", "period_end", "periodend",
    "interval_time", "intervaltime", "interval_ts", "intervalts",
    "reading_time", "readingtime", "read_time", "readtime", "read_ts",
    "readts", "end_interval", "endinterval", "interval_finish",
    "intervalfinish", "fin_intervalo", "finintervalo", "fin_intervalle",
    "finintervalle", "intervallende", "fine_intervallo", "fineintervallo",
    "interval_end_time", "intervalendtime", "enddt", "end_dt",
    "datetime_end", "datetimeend",
]
 
START_KEYS = [
    "interval_start", "intervalstart", "start_time", "starttime",
    "start_ts", "startts", "period_start", "periodstart", "start_interval",
    "startinterval", "interval_begin", "intervalbegin", "begin_time",
    "begintime", "debut_intervalle", "debutintervalle", "inicio_intervalo",
    "iniciointervalo", "datetime_start", "datetimestart",
]
 
TIME_FALLBACK = [
    "datetime", "timestamp", "time_stamp", "time", "ts", "dt",
    "readingdt", "reading_dt", "local_time", "localtime", "utc",
    "utctime", "utc_time", "read_datetime", "readdatetime",
]
 
KWH_KEYS = [
    "kwh", "usage", "usage_kwh", "usagekwh", "energy", "energy_kwh",
    "energykwh", "consumption", "consumption_kwh", "consumptionkwh",
    "interval_kwh", "intervalkwh", "delta_kwh", "deltakwh", "delta",
    "kwh_usage", "kwhusage", "active_energy", "activeenergy", "delivered",
    "kwh_in", "kwhin", "kwhd", "kwh_d", "qty", "quantity", "interval_value",
    "intervalvalue", "channel1", "ch1", "wh_interval", "interval_wh",
    "consumo", "consommation", "energie", "verbrauch", "energia",
    "value_kwh", "valuekwh", "usagewh", "usage_wh", "intervalenergy",
    "interval_energy", "interval_usage", "intervalusage",
]
 
WH_USAGE_KEYS = {
    "wh", "watt_hours", "watthours", "usage_wh", "usagewh", "interval_wh",
    "intervalwh", "wh_interval", "whinterval",
}
 
REGISTER_KEYS = [
    "register", "register_kwh", "registerkwh", "cumulative", "cumulative_kwh",
    "cumulativekwh", "total", "total_kwh", "totalkwh", "index", "index_kwh",
    "indexkwh", "reading", "dial", "encoder", "register_value",
    "registervalue", "running_total", "runningtotal", "counter",
    "zaehlerstand", "stand", "leitura", "lectura", "billing_index",
    "billingindex", "encoder_value", "encodervalue", "register_wh",
    "registerwh", "totalizer", "totaliser", "accum", "accumulated",
    "accumulated_kwh", "cum_kwh", "cumkwh",
    "registro", "registrador", "indice",
]
 
WH_REGISTER_KEYS = {
    "register_wh", "registerwh", "total_wh", "totalwh", "index_wh", "indexwh",
}
 
QUALITY_KEYS = [
    "quality", "q", "qflag", "q_flag", "quality_flag", "qualityflag",
    "data_quality", "dataquality", "read_quality", "readquality",
    "qualite", "calidad", "qualitaet", "qualita",
    "uom_quality", "uomquality", "source_quality", "sourcequality",
    "estimation_flag", "estimationflag", "quality_code", "qualitycode",
    "readstatus", "read_status", "is_estimated", "isestimated",
    "qstatus", "qualitystatus", "quality_status",
]
 
KEY_NORM_RE = re.compile(r"[^a-z0-9]+")
METER_RE = re.compile(r"(?<![A-Z0-9])M-?(\d{5,7})(?!\d)", re.I)
METER_DIGITS_RE = re.compile(r"^\d{5,7}$")
TRAIL_COMMA_RE = re.compile(r",\s*([}\]])")
UNQUOTED_KEY_RE = re.compile(r"([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:")
KV_RE = re.compile(
    r'["\']?([A-Za-z_][A-Za-z0-9_]*)["\']?\s*:\s*'
    r'(?:["\']([^"\']*)["\']|(-?\d+(?:\.\d+)?)|(true|false|null))',
    re.I,
)
JSONISH_RE = re.compile(r"[{\[]")
UNIT_RE = re.compile(
    r"(?i)\s*(?:kwh|kw\.h|kwhr|kilowatthours?|mwh|wh|watthours?|kw|kwhs)\s*$"
)
NON_NUMERIC_RE = re.compile(r"[^0-9,.\-eE+]")
WRAP_KEYS = {
    "message", "payload", "body", "data", "record", "after", "new",
    "newvalues", "newrecord", "reading", "content", "item",
}
 
QUANT = Decimal("0.001")
THIRTY = timedelta(minutes=30)
EPOCH_MIN = 946684800
EPOCH_MAX = 2051222400
 
 
def norm_key(k):
    if not isinstance(k, str):
        k = str(k)
    return KEY_NORM_RE.sub("", k.strip().lower())
 
 
def is_null(v):
    if v is None:
        return True
    if isinstance(v, bool):
        return False
    if isinstance(v, str):
        return v.strip().lower() in NULL_SPELLINGS
    return False
 
 
def fmt3(d):
    try:
        q = d.quantize(QUANT, rounding=ROUND_HALF_EVEN)
    except InvalidOperation:
        return None
    s = format(q, "f")
    if "." not in s:
        s += ".000"
    else:
        whole, frac = s.split(".", 1)
        frac = (frac + "000")[:3]
        s = whole + "." + frac
    return s
 
 
def parse_number(v, as_wh=False):
    if v is None or isinstance(v, (dict, list, bool)):
        return None
    unit = "wh" if as_wh else None
    if isinstance(v, int):
        d = Decimal(v)
    elif isinstance(v, float):
        if math.isnan(v) or math.isinf(v):
            return None
        d = Decimal(str(v))
    else:
        s = html.unescape(str(v)).strip()
        if not s or s.lower() in NULL_SPELLINGS:
            return None
        sl = s.lower().replace(" ", "")
        if sl.endswith("mwh"):
            unit = "mwh"
        elif sl.endswith("kwh") or sl.endswith("kw.h") or sl.endswith("kwhr"):
            unit = "kwh"
        elif sl.endswith("wh") or sl.endswith("watthour") or sl.endswith("watthours"):
            unit = "wh"
        s = UNIT_RE.sub("", s).strip()
        s = s.replace("$", "").replace("€", "").replace("£", "").strip()
        if not s or s.lower() in NULL_SPELLINGS:
            return None
        if "," in s and "." in s:
            if s.rfind(".") > s.rfind(","):
                s = s.replace(",", "")
            else:
                s = s.replace(".", "").replace(",", ".")
        elif "," in s:
            left, right = s.rsplit(",", 1)
            if right.isdigit() and 1 <= len(right) <= 3 and "." not in left:
                s = left.replace(".", "") + "." + right
            else:
                s = s.replace(",", "")
        s = s.replace(" ", "")
        try:
            d = Decimal(s)
        except InvalidOperation:
            s2 = NON_NUMERIC_RE.sub("", str(v))
            if not s2 or s2 in {".", "-", "+", ""}:
                return None
            try:
                d = Decimal(s2)
            except InvalidOperation:
                return None
    if unit == "wh":
        d = d / Decimal(1000)
    elif unit == "mwh":
        d = d * Decimal(1000)
    return d
 
 
def parse_quality(v):
    if v is None or isinstance(v, (dict, list)):
        return None
    if isinstance(v, bool):
        return "actual" if v else None
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        if v == 1:
            return "actual"
        if v == 2:
            return "estimated"
        return None
    s = html.unescape(str(v)).strip().lower()
    if not s or s in NULL_SPELLINGS:
        return None
    s = s.replace(" ", "").replace("-", "").replace("_", "").replace("/", "")
    if s in ACTUAL or "actual" in s or s.startswith("act"):
        return "actual"
    if s in ESTIMATED or "estimat" in s or "subst" in s:
        return "estimated"
    if s in {"s"}:
        return "estimated"
    return None
 
 
def parse_meter_id(v):
    if v is None or isinstance(v, (dict, list, bool)):
        return None
    if isinstance(v, float):
        if not v.is_integer():
            return None
        v = int(v)
    s = html.unescape(str(v)).strip().upper()
    if not s or s.lower() in NULL_SPELLINGS:
        return None
    s = s.replace(" ", "").replace("_", "")
    m = METER_RE.search(s)
    if m:
        return "M-" + m.group(1).zfill(7)
    if METER_DIGITS_RE.match(s):
        return "M-" + s.zfill(7)
    return None
 
 
def _from_epoch(n):
    try:
        n = float(n)
    except (TypeError, ValueError):
        return None
    if n > 1e14:
        n /= 1e6
    elif n > 1e11:
        n /= 1e3
    if n < EPOCH_MIN or n > EPOCH_MAX:
        return None
    try:
        return datetime.fromtimestamp(n, tz=timezone.utc)
    except (ValueError, OSError, OverflowError):
        return None
 
 
def parse_datetime(v):
    if v is None or isinstance(v, (dict, list, bool)):
        return None
    if isinstance(v, datetime):
        dt = v
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        else:
            dt = dt.astimezone(timezone.utc)
        return dt
    if isinstance(v, (int, float)):
        return _from_epoch(v)
    s = html.unescape(str(v)).strip()
    if not s or s.lower() in NULL_SPELLINGS:
        return None
    if s.isdigit() or (s[0] in "+-" and s[1:].isdigit()):
        return _from_epoch(s)
    try:
        n = float(s)
    except ValueError:
        n = None
    if n is not None and 1e9 <= abs(n) <= 1e14:
        dt = _from_epoch(n)
        if dt is not None:
            return dt
    s2 = s.replace("Z", "+00:00") if s.endswith("Z") else s
    try:
        dt = datetime.fromisoformat(s2)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        else:
            dt = dt.astimezone(timezone.utc)
        return dt
    except ValueError:
        pass
    s3 = s.replace("T", " ").replace("Z", "").strip()
    for fmt in (
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y/%m/%d %H:%M:%S",
        "%Y/%m/%d %H:%M",
        "%m/%d/%Y %H:%M:%S",
        "%m/%d/%Y %H:%M",
        "%m/%d/%Y %I:%M:%S %p",
        "%m/%d/%Y %I:%M %p",
        "%d/%m/%Y %H:%M:%S",
        "%Y-%m-%d",
        "%Y/%m/%d",
        "%m/%d/%Y",
    ):
        try:
            dt = datetime.strptime(s3, fmt).replace(tzinfo=timezone.utc)
            return dt
        except ValueError:
            continue
    return None
 
 
def align_end(dt, is_start=False):
    if dt is None:
        return None
    dt = dt.astimezone(timezone.utc).replace(microsecond=0)
    if is_start:
        dt = dt + THIRTY
    dt = dt.replace(second=0)
    m = dt.minute
    if m == 0 or m == 30:
        pass
    elif m < 30:
        dt = dt.replace(minute=30)
    else:
        dt = (dt.replace(minute=0) + timedelta(hours=1))
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
 
 
def repair_json_text(s):
    s = html.unescape(s)
    if s and s[0] == "\ufeff":
        s = s.lstrip("\ufeff")
    s = s.strip()
    if not s:
        return s
    m = JSONISH_RE.search(s)
    if m and m.start() > 0:
        s = s[m.start():]
    s = TRAIL_COMMA_RE.sub(r"\1", s)
    s = UNQUOTED_KEY_RE.sub(r'\1"\2":', s)
    s = s.replace("None", "null").replace("True", "true").replace("False", "false")
    if "'" in s and '"' not in s:
        s = s.replace("'", '"')
    return s
 
 
def try_json(s):
    try:
        return json.loads(s)
    except (ValueError, TypeError):
        return None
 
 
def close_truncated(s):
    t = s.rstrip()
    if t.endswith(","):
        t = t[:-1]
    in_str = False
    esc = False
    quote = None
    braces = 0
    brackets = 0
    for ch in t:
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == quote:
                in_str = False
            continue
        if ch in "\"'":
            in_str = True
            quote = ch
        elif ch == "{":
            braces += 1
        elif ch == "}":
            braces -= 1
        elif ch == "[":
            brackets += 1
        elif ch == "]":
            brackets -= 1
    if in_str:
        t += quote if quote else '"'
    t += "]" * max(0, brackets)
    t += "}" * max(0, braces)
    return t
 
 
def kv_fallback(s):
    out = {}
    for m in KV_RE.finditer(s):
        k, sval, nval, bval = m.group(1), m.group(2), m.group(3), m.group(4)
        if sval is not None:
            out[k] = sval
        elif nval is not None:
            if "." in nval:
                try:
                    out[k] = float(nval)
                except ValueError:
                    out[k] = nval
            else:
                try:
                    out[k] = int(nval)
                except ValueError:
                    out[k] = nval
        elif bval is not None:
            bl = bval.lower()
            out[k] = True if bl == "true" else False if bl == "false" else None
    return out or None
 
 
def parse_raw(raw):
    if raw is None:
        return None
    if isinstance(raw, bytes):
        try:
            raw = raw.decode("utf-8", "replace")
        except Exception:
            return None
    if not isinstance(raw, str):
        raw = str(raw)
    s = raw.strip()
    if not s:
        return None
    obj = try_json(s)
    if obj is None:
        repaired = repair_json_text(s)
        obj = try_json(repaired)
        if obj is None:
            obj = try_json(close_truncated(repaired))
        if obj is None:
            obj = kv_fallback(repaired)
    if obj is None:
        return None
    if isinstance(obj, str):
        inner = try_json(obj.strip())
        if inner is not None:
            obj = inner
        else:
            return None
    return obj
 
 
def expand_strings(obj, depth=0):
    if depth > 4:
        return obj
    if isinstance(obj, dict):
        for k, v in list(obj.items()):
            if isinstance(v, str):
                t = v.strip()
                if t[:1] in "{[":
                    parsed = try_json(t)
                    if parsed is None:
                        parsed = try_json(repair_json_text(t))
                    if isinstance(parsed, (dict, list)):
                        obj[k] = parsed
                        v = parsed
            if isinstance(v, (dict, list)):
                expand_strings(v, depth + 1)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            if isinstance(v, str):
                t = v.strip()
                if t[:1] in "{[":
                    parsed = try_json(t)
                    if isinstance(parsed, (dict, list)):
                        obj[i] = parsed
                        v = parsed
            if isinstance(v, (dict, list)):
                expand_strings(v, depth + 1)
    return obj
 
 
def collect_dicts(obj, out, depth=0):
    if depth > 6:
        return
    if isinstance(obj, dict):
        out.append(obj)
        for v in obj.values():
            if isinstance(v, (dict, list)):
                collect_dicts(v, out, depth + 1)
    elif isinstance(obj, list):
        for v in obj:
            if isinstance(v, (dict, list)):
                collect_dicts(v, out, depth + 1)
 
 
def lookup(dicts, names):
    name_set = names if isinstance(names, set) else set(names)
    for d in dicts:
        for k, v in d.items():
            if is_null(v) or isinstance(v, (dict, list)):
                continue
            if norm_key(k) in name_set:
                return v
            nk = norm_key(k)
            if nk in name_set:
                return v
    return None
 
 
def lookup_norm(dicts, names):
    want = {norm_key(n) for n in names}
    for d in dicts:
        for k, v in d.items():
            if is_null(v) or isinstance(v, (dict, list)):
                continue
            if norm_key(k) in want:
                return v, norm_key(k)
    return None, None
 
 
def is_correction(dicts):
    for d in dicts:
        for k, v in d.items():
            nk = norm_key(k)
            if nk in {"event", "eventtype", "type", "op", "kind", "action", "changetype"}:
                s = str(v).strip().lower()
                if s in {
                    "change", "correction", "update", "u", "cdc", "revise",
                    "revised", "amend", "amended", "fix", "edited", "edit",
                }:
                    return True
            if nk in {"correction", "iscorrection", "corrected", "ischange"}:
                if v is True or str(v).strip().lower() in {"true", "1", "yes"}:
                    return True
    return False
 
 
def unwrap_record(obj, depth=0):
    if depth > 5 or not isinstance(obj, dict):
        return obj
    expand_strings(obj)
    for k, v in list(obj.items()):
        if norm_key(k) not in WRAP_KEYS:
            continue
        inner = v
        if isinstance(inner, str):
            parsed = parse_raw(inner)
            if parsed is None:
                continue
            inner = parsed
        if isinstance(inner, dict):
            merged = dict(obj)
            merged.pop(k, None)
            merged.update(inner)
            return unwrap_record(merged, depth + 1)
        if isinstance(inner, list):
            return inner
    return obj
 
 
def iter_records(obj):
    if obj is None:
        return
    if isinstance(obj, list):
        for item in obj:
            yield from iter_records(item)
        return
    if not isinstance(obj, dict):
        return
    obj = unwrap_record(obj)
    if isinstance(obj, list):
        yield from iter_records(obj)
        return
    for k, v in list(obj.items()):
        if norm_key(k) in {"records", "readings", "items", "rows", "events"} and isinstance(v, list):
            if v and all(isinstance(x, (dict, str)) for x in v):
                for item in v:
                    if isinstance(item, str):
                        parsed = parse_raw(item)
                        if parsed is not None:
                            yield from iter_records(parsed)
                    elif isinstance(item, dict):
                        merged = dict(obj)
                        merged.pop(k, None)
                        merged.update(item)
                        yield from iter_records(merged)
                return
    yield obj
 
 
def clean_record(rec):
    dicts = []
    collect_dicts(rec, dicts)
    if not dicts:
        return None
 
    meter = parse_meter_id(lookup(dicts, {norm_key(n) for n in METER_KEYS}))
    if meter is None:
        for d in dicts:
            for key, v in d.items():
                if not isinstance(v, dict):
                    continue
                if norm_key(key) not in {
                    "meter", "device", "endpoint", "asset", "medidor",
                    "compteur", "zaehler", "contatore",
                }:
                    continue
                for ik, iv in v.items():
                    if norm_key(ik) in {"id", "serial", "number", "no", "name", "code"} | {norm_key(n) for n in METER_KEYS}:
                        meter = parse_meter_id(iv)
                        if meter:
                            break
                if meter:
                    break
            if meter:
                break
    if meter is None:
        for d in dicts:
            for k, v in d.items():
                if norm_key(k) in BOOKKEEPING:
                    continue
                if isinstance(v, (dict, list, bool)):
                    continue
                meter = parse_meter_id(v)
                if meter:
                    break
            if meter:
                break
    if meter is None:
        return None
 
    end_v, end_k = lookup_norm(dicts, END_KEYS)
    is_start = False
    if end_v is None:
        end_v, end_k = lookup_norm(dicts, START_KEYS)
        is_start = end_v is not None
    if end_v is None:
        end_v, end_k = lookup_norm(dicts, TIME_FALLBACK)
        is_start = False
        if end_k in {norm_key(b) for b in BOOKKEEPING}:
            end_v = None
    interval_end = align_end(parse_datetime(end_v), is_start=is_start)
    if interval_end is None:
        return None
 
    kwh_v, kwh_k = lookup_norm(dicts, KWH_KEYS + list(WH_USAGE_KEYS))
    as_wh = bool(kwh_k and kwh_k in WH_USAGE_KEYS)
    usage = parse_number(kwh_v, as_wh=as_wh)
    usage_s = fmt3(usage) if usage is not None else None
 
    reg_v, reg_k = lookup_norm(dicts, REGISTER_KEYS + list(WH_REGISTER_KEYS))
    as_wh_r = bool(reg_k and reg_k in WH_REGISTER_KEYS)
    register = parse_number(reg_v, as_wh=as_wh_r)
    register_s = fmt3(register) if register is not None else None
 
    quality = parse_quality(lookup(dicts, {norm_key(n) for n in QUALITY_KEYS}))
 
    rank = 3 if is_correction(dicts) else 2 if quality == "actual" else 1 if quality == "estimated" else 0
    return meter, interval_end, usage_s, register_s, quality, rank
 
 
class Handler:
    def __init__(self):
        self.held = {}
 
    def _merge(self, key, usage, register, quality, rank):
        old = self.held.get(key)
        if old is None:
            self.held[key] = [usage, register, quality, rank]
            return
        ou, orr, oq, ora = old
        if rank < ora:
            return
        if rank > ora:
            old[0] = usage if usage is not None else ou
            old[1] = register if register is not None else orr
            old[2] = quality if quality is not None else oq
            old[3] = rank
            return
        if usage is not None:
            old[0] = usage
        if register is not None:
            old[1] = register
        if quality is not None:
            old[2] = quality
 
    def process(self, raw):
        try:
            obj = parse_raw(raw)
            if obj is None:
                return []
            for rec in iter_records(obj):
                try:
                    row = clean_record(rec)
                except Exception:
                    continue
                if not row:
                    continue
                meter, interval_end, usage, register, quality, rank = row
                self._merge(meter + "|" + interval_end, usage, register, quality, rank)
            return []
        except Exception:
            return []
 
    def finalize(self):
        by_meter = defaultdict(list)
        for key, rec in self.held.items():
            meter, end = key.split("|", 1)
            by_meter[meter].append((end, rec))
        for items in by_meter.values():
            items.sort(key=lambda x: x[0])
            prev_ts = None
            prev_reg = None
            for end, rec in items:
                try:
                    ts = int(datetime.strptime(end, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp())
                except ValueError:
                    prev_ts = None
                    prev_reg = None
                    continue
                reg = None
                if rec[1] is not None:
                    try:
                        reg = Decimal(rec[1])
                    except InvalidOperation:
                        reg = None
                if rec[0] is None and reg is not None and prev_reg is not None and prev_ts is not None:
                    if ts - prev_ts == 1800:
                        delta = reg - prev_reg
                        if delta >= 0:
                            rec[0] = fmt3(delta)
                if reg is not None:
                    prev_reg = reg
                    prev_ts = ts
                else:
                    prev_reg = None
                    prev_ts = None
        out = []
        for key, rec in self.held.items():
            meter, end = key.split("|", 1)
            out.append({
                "meter_id": meter,
                "interval_end": end,
                "usage_kwh": rec[0],
                "register_kwh": rec[1],
                "quality": rec[2],
            })
        return out
