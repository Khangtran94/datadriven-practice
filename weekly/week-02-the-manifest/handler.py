import json
import re
from datetime import datetime, timezone

                    ### Define mapping values
VALID_RENDITIONS = {"240p", "360p", "480p", "720p", "1080p", "2160p"}
WIDTH_TO_RENDITION = {426: "240p",640: "360p",854: "480p",1280: "720p",1920: "1080p",3840: "2160p"}
VALID_CODECS = {"h264", "h265", "av1", "vp9"}
CODEC_ALIASES = {"264": "h264","h264": "h264","avc": "h264","265": "h265","h265": "h265","hevc": "h265","av1": "av1","vp9": "vp9","1":"av1","9":"vp9"}
 
                    ### Lines are written by a logger, not a serializer
_LOGGER_NESTED_FIELDS = ("message", "msg", "log", "data", "payload", "body")
def _try_parse_dict(text):
    """Best-effort parse of text as a JSON dict."""
    try:
        obj = json.loads(text)
        return obj if isinstance(obj, dict) else None
    except (json.JSONDecodeError, TypeError):
        return None
 
def _looks_like_data(rec):
    """True if this dict has at least one key we actually recognize —
    i.e. it's plausibly the record we want, not bookkeeping/log noise."""
    return any(_normalize_key_name(k) in _ALIAS_LOOKUP for k in rec)
 
def extract_json_payload(raw):
    """
    Pull the actual data record out of a raw log line.
    Tries, in order: the whole line as-is; the substring between the
    first '{' and last '}'; and, if that dict doesn't contain any
    recognized field, one level of unwrapping through common logger
    wrapper keys (message/data/payload/...). Returns a dict or None.
    """
    if not isinstance(raw, str):
        return None
    candidates = [raw]
    start, end = raw.find("{"), raw.rfind("}")
    if start != -1 and end != -1 and end > start:
        candidates.append(raw[start:end + 1])
    for candidate in candidates:
        obj = _try_parse_dict(candidate)
        if obj is None:
            continue
        if _looks_like_data(obj):
            return obj
        # Not directly recognizable — maybe the real payload is nested
        # inside a logger wrapper field as a JSON/dict string.
        for field in _LOGGER_NESTED_FIELDS:
            inner = obj.get(field)
            if isinstance(inner, str):
                nested = _try_parse_dict(inner)
                if nested is not None and _looks_like_data(nested):
                    return nested
            elif isinstance(inner, dict) and _looks_like_data(inner):
                return inner
    return None  
 
        ### Key-variant mapping (raw JSON key -> canonical field)
KEY_ALIASES = {
    "title_id":  ["title_id", "titleid", "title-id", "title", "id", "content_id", "asset_id", "assetid"],
    "variant":   ["variant", "rendition", "resolution", "quality", "res", "height", "width"],
    "codec":     ["codec", "video_codec", "vcodec", "encoding", "enc"],
    "bitrate":   ["bitrate", "bit_rate", "kbps", "bitrate_kbps", "bitratekbps"],
    "duration":  ["duration", "duration_s", "duration_sec", "length", "runtime"],
    "packaged":  ["packaged", "packaged_at", "packagedat", "timestamp", "created_at", "createdat"]}

def _normalize_key_name(k):
    """Collapse a raw key to a bare lowercase alnum string so
    'Title_ID', 'title-id', 'titleId' all compare equal."""
    return re.sub(r"[^a-z0-9]", "", str(k).lower())
 
# Build reverse lookup once: normalized_alias -> canonical_field
_ALIAS_LOOKUP = {
    _normalize_key_name(alias): canonical
    for canonical, aliases in KEY_ALIASES.items()
    for alias in aliases
}

def normalize_keys(rec):
    """
    Map an incoming record's arbitrary key names onto the canonical
    keys clean() expects (title_id, variant, codec, bitrate, duration, packaged).
 
    If two raw keys map to the same canonical field, the first non-null
    value wins and later ones are ignored (order = dict iteration order).
    Unrecognized keys are dropped silently.
    """
    if not isinstance(rec, dict):
        return {}
    out = {}
    for raw_key, value in rec.items():
        canonical = _ALIAS_LOOKUP.get(_normalize_key_name(raw_key))
        if canonical is None:
            continue
        if out.get(canonical) is None:
            out[canonical] = value
    return out

                    ### Normalize function
def parse_title_id(val):
    if not isinstance(val, str):
        return None
    val = val.strip().upper()
    return val if val else None

def normalize_rendition(variant):
    """
    Normalize a variant value into a rendition string.
    Examples:
        240       -> "240p"
        "240"     -> "240p"
        "720P"    -> "720p"
        "720p"    -> "720p"
        1920      -> "1080p"
        "1920w"   -> "1080p"
        "1920 w"  -> "1080p"
        "1920 wide" -> "1080p"
    Returns:
        str | None: normalized rendition, or None if invalid.
    """
    if variant is None:
        return None
    value = str(variant).strip().lower()
    # Already has "p": 240p, 720P, 1080 p
    match = re.fullmatch(r"(\d+)\s*p", value)
    if match:
        rendition = f"{match.group(1)}p"
        return rendition if rendition in VALID_RENDITIONS else None  
    # Width with optional "w" / "wide" / "width":
    match = re.fullmatch(r"(\d+)\s*(?:w|wide|width)?", value)
    if not match:
        return None
    number = int(match.group(1))
    # Case 1: number is directly a valid rendition
    rendition = f"{number}p"
    if rendition in VALID_RENDITIONS:
        return rendition
    # Case 2: number is a known video width
    if number in WIDTH_TO_RENDITION:
        return WIDTH_TO_RENDITION[number]
    # Case 3: number is neither
    return None
    
def normalize_codec(codec):
    if codec is None:
        return None
    if isinstance(codec, int):
        value = str(codec)
    elif isinstance(codec, str):
        value = codec.strip().lower()
    else:
        return None
    # Returns only h264, h265, av1, vp9, or None
    return CODEC_ALIASES.get(value)

def normalize_bitrate(bitrate):
    if bitrate is None:
        return None
    if isinstance(bitrate, (int,float)):
        return int(bitrate)
    if isinstance(bitrate, str):
        match = re.search(r"\d+", bitrate)
        if match:
            return int(match.group())
    return None

def normalize_duration(duration):
    if duration is None:
        return None
    if isinstance(duration, (int, float)):
        return round(float(duration), 3)
    if isinstance(duration, str):
        match = re.search(
            r"(\d+(?:\.\d+)?)\s*(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h)?",
            duration.lower())
        if not match:
            return None
        value = float(match.group(1))
        unit = match.group(2)
        if unit in {"minutes", "minute", "mins", "min", "m"}:
            value *= 60
        elif unit in {"hours", "hour", "hrs", "hr", "h"}:
            value *= 3600
        return round(value, 3)
    return None

def normalize_packaged(packaged):
    if packaged is None:
        return None
    if isinstance(packaged, bool):
        return None
    # Unix timestamp
    if isinstance(packaged, (int, float)):
        try:
            dt = datetime.fromtimestamp(
                float(packaged),
                tz=timezone.utc)
            return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        except (OSError, ValueError, OverflowError):
            return None
    if not isinstance(packaged, str):
        return None
    packaged = packaged.strip()
    if not packaged:
        return None
    # NEW: nzumeric string -> treat as unix timestamp
    try:
        num = float(packaged)
        dt = datetime.fromtimestamp(num, tz=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except (ValueError, OSError, OverflowError):
        pass  # not a plain number, fall through to ISO parsing
    # ISO 8601
    try:
        dt = datetime.fromisoformat(packaged)
        # No timezone -> assume UTC
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        else:
            dt = dt.astimezone(timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return None
    
                    ### Quality check — run BEFORE clean(), on the key-normalized dict
def check_quality(rec):
    """
    A row is only worth keeping if we can determine its identity
    (title_id + rendition — that's the dedupe key) and compare it for
    recency (packaged_at). codec/bitrate/duration are NOT gated here:
    a genuine null on one of those is free/correct, so dropping an
    otherwise-identifiable row over one soft field only loses credit
    for the fields that *did* parse, for no benefit.
    """
    if not isinstance(rec, dict) or not rec:
        return False
    if parse_title_id(rec.get("title_id")) is None:
        return False
    if normalize_rendition(rec.get("variant")) is None:
        return False
    if normalize_packaged(rec.get("packaged")) is None:
        return False
    return True

def clean(rec):
    if not isinstance(rec, dict):
        return None
    title = parse_title_id(rec.get('title_id'))
    if title is None:
        return None
    return {
        'title_id': title,
        'rendition': normalize_rendition(rec.get("variant")),
        'codec': normalize_codec(rec.get("codec")),
        'bitrate_kbps': normalize_bitrate(rec.get("bitrate")),
        'duration_s': normalize_duration(rec.get("duration")),
        'packaged_at': normalize_packaged(rec.get("packaged"))
    }

class Handler:
    def __init__(self):
        self.records = {}
    def process(self, raw):
        try:
            payload = extract_json_payload(raw)
            if payload is None:
                return []
            normalized = normalize_keys(payload)
            if not check_quality(normalized):
                return []
            row = clean(normalized)
            if row is None:
                return []

            key = (row['title_id'], row['rendition'])
            existing = self.records.get(key)

            # Skip if this record is older than what we already have for this key
            if existing is not None and row['packaged_at'] <= existing['packaged_at']:
                return []
            self.records[key] = row
            return [row]  
        except (TypeError, ValueError, KeyError, AttributeError, OverflowError, OSError):
            return []
    
    def finalize(self):
        return [] 
