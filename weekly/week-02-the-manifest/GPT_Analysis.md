# Week 2 – The Manifest: handler.py vs gold_submit.py

## Result

- **Score:** 0.8266
- **Rank:** #3 of 9
- **Records recovered:** 806,315 / 928,817
- **Work per record:** 2.1× median
- **Measured duplicate-row penalty:** 14 second rows cost 28 points

Files: [handler.py](./handler.py) and [gold_submit.py](./gold_submit.py). Function names are used as anchors because line numbers may shift. Analysis filename convention: `GPT_Analysis.md` (case-sensitive).

## Impact ranking

| Priority | Gap | Evidence / impact |
|---:|---|---|
| 1 | Output lifecycle and final-state deduplication | **Measured:** 14 second rows for an existing key cost 28 points. process emits rows immediately; finalize returns nothing. |
| 2 | Job-close context and pending outputs | Job-close lines are 2.5% of the stream; only 1% recovered. Outputs can arrive before the close line supplies the title. |
| 3 | Nested records and multiple renditions | Nesting/flattening is 4% of the stream, with 28% recovered; rung variants are 6%, with 27% recovered. |
| 4 | Logger-tolerant JSON parsing | Broken JSON is 3% of the stream, with 36% recovered; truncated lines are 0.5%, with 1% recovered. |
| 5 | Rendition, codec, rate, duration, and timestamp normalization | Several 4–6% conditions are only partly handled, including codec tags, rate units, duration formats, epoch milliseconds, and mixed dates. |
| 6 | Same-time field reconciliation | The handler discards every record whose timestamp is not strictly newer; gold can merge complementary values for the same instant. |

The README directly quantifies the 28-point duplicate penalty. Condition-level recovery rates identify weak patterns but do not provide an exact score loss for each condition.

---

## 1. Hold candidates and emit the final table from finalize()

### Your code — handler.py, Handler.process() / Handler.finalize()

~~~python
key = (row['title_id'], row['rendition'])
existing = self.records.get(key)

if existing is not None and row['packaged_at'] <= existing['packaged_at']:
    return []
self.records[key] = row
return [row]

def finalize(self):
    return []
~~~

### Gold code — gold_submit.py

The gold process updates in-memory state and returns an empty list. finalize flushes pending job outputs and returns the completed held rows.

### Example input

~~~json
{"title_id":"T-0000001","variant":"720p","packaged_at":"2026-09-01T10:00:00Z","codec":"h264"}
{"title_id":"T-0000001","variant":"720p","packaged_at":"2026-09-01T11:00:00Z","codec":"h265"}
~~~

### Your behavior

The first call emits the 10:00 row immediately. The second call replaces the in-memory candidate and emits the 11:00 row too. The output contains two rows for one key, even though the dictionary holds only the latest row at the end.

### Gold behavior

Both process calls return no rows. The candidate is updated in memory, and only the final chosen row is emitted from finalize.

### Why it matters

The README reports 14 second rows for existing keys, costing 28 points. A deduplicated dictionary does not help if intermediate versions have already escaped downstream.

### What to change

- Make process parse, normalize, validate, and update state only.
- Return [] from every process path.
- Return the complete final table from finalize.
- Keep identity-key logic separate from winner selection.

---

## 2. Keep job context so close lines can complete earlier outputs

### Your code

A row is accepted only when its current payload already contains a valid title ID, rendition, and package timestamp. There is no pending-job state or close-line reconciliation.

### Gold code

The gold implementation tracks job context and pending outputs. When a close record supplies information missing from earlier output records, pending records can inherit that context before final emission.

### Example input

~~~json
{"job_id":"J-42","variant":"720p","codec":"h264","bitrate":"2500 kbps"}
{"job_id":"J-42","title_id":"T-0000001","event":"job_closed"}
~~~

This illustrates the feed pattern: the output has rendition-level details and a job ID, while the later close record supplies the title. The close record itself is not a rendition row.

### Your behavior

The first record fails identity validation because the title is missing. The close record has no rendition and is not emitted as a row. The relationship between the two records is lost.

### Gold behavior

The output is held under the job ID. The close record updates job context, allowing pending output to be completed when the necessary fields are available.

### Why it matters

Job-close lines are 2.5% of the stream and only 1% recovered. This is a lifecycle/context problem, not merely a field-alias problem.

### What to change

Maintain explicit state such as jobs[job_id] and pending_outputs[job_id]. On each record, update job context or append an output. On close, enrich pending outputs, validate them, and merge viable rows into the held candidate map. Do not emit the close line as a rendition.

---

## 3. Flatten nested payloads and expand rendition lists

### Your code — extract_json_payload() and normalize_keys()

The parser recognizes the top-level dictionary or unwraps one known logger field by one level. normalize_keys maps aliases but drops unrecognized keys and does not recursively flatten nested structures.

### Gold code — _flatten() and _expand()

The gold implementation recursively flattens known containers and expands lists/dictionaries of outputs, renditions, variants, representations, streams, or records. Parent metadata can be merged with each child rendition.

### Example input

~~~json
{
  "asset": {"title_id": "T-0000001"},
  "video": {"codec": "avc1", "bitrate": "2.5 Mbps"},
  "outputs": [
    {"profile": "1280x720", "duration_ms": 120000},
    {"profile": "1920x1080", "duration_ms": 120000}
  ]
}
~~~

### Your behavior

The outer object may be extracted, but the flat alias mapper cannot reliably combine nested asset/video fields with each item in outputs. It does not create one output row per child rendition.

### Gold behavior

The gold path flattens nested metadata, expands each output, merges parent context into each child, and normalizes each rendition independently.

### Why it matters

The README reports 28% recovery for nesting/flattening and 27% for rung-as-size/name/number. Finding a nested profile is not enough unless its representation is also interpreted.

### What to change

Separate parsing, flattening, expansion, and normalization. Test nested parent metadata, child overrides, list-valued outputs, dictionary-valued outputs, and width/height objects. Preserve child-specific values when merging parent fields.

---

## 4. Use a tolerant parser for logger-produced JSON

### Your code — extract_json_payload()

The implementation tries strict json.loads on the whole line and then on the substring from the first opening brace to the last closing brace. It returns no payload if both attempts fail.

### Gold code — _parse() and _LooseJSON

The gold path strips a BOM and surrounding control characters, tries normal JSON decoding, searches for an embedded object/array in logger text, and uses a constrained fallback parser for common logger syntax and incomplete objects.

### Example input

~~~text
2026-09-01T10:00:00Z INFO packager payload={"title_id":"T-0000001","variant":"720p","codec":"h264",}
~~~

The trailing comma is illustrative of a logger format strict JSON rejects.

### Your behavior

Neither the full line nor the brace-delimited substring is valid strict JSON, so the payload is dropped.

### Gold behavior

The parser attempts recovery from the embedded object and tolerates selected logger irregularities while retaining recoverable fields.

### Why it matters

Broken JSON accounts for 3% of the stream, with 36% recovered. Truncated lines are more severe: 0.5% of the stream and only 1% recovered. No parser can reconstruct fields that were never written, so recovery must be conservative.

### What to change

Use a staged parser: strict JSON first, embedded JSON second, bounded loose-parser fallback third. Never use eval. Test logger prefixes/suffixes, BOMs, trailing commas, comments, escaped/unescaped quotes, and truncated objects. Return only defensible fields.

---

## 5. Normalize semantic values, not just strings

### Your code

- normalize_rendition supports known height strings and configured widths.
- normalize_codec uses a small exact alias map.
- normalize_bitrate extracts the first integer from a string.
- normalize_duration handles a limited set of units.
- normalize_packaged treats numeric values as epoch seconds.

### Gold code

The gold implementation uses richer rendition parsing, codec-tag recognition, decimal-aware number/unit parsing, duration conversions, and timestamp handling that distinguishes likely seconds from milliseconds.

### Example input

~~~json
{
  "title_id": "T-0000001",
  "variant": {"width": 1920, "height": 1080},
  "codec": "avc1.640028",
  "bitrate": "2.5 Mbps",
  "duration": "120000 ms",
  "packaged_at": "1798845600000"
}
~~~

### Your behavior

The rendition object is not converted to a width-based rendition. The codec tag is not an exact alias. Bitrate parsing can turn 2.5 Mbps into 2 instead of 2500 kbps. Duration in milliseconds is not converted to seconds, and a millisecond epoch can be interpreted as seconds.

### Gold behavior

The gold parsers recognize broader representations and convert them into the canonical schema, using decimal arithmetic where precision and unit conversion matter.

### Why it matters

The README shows sizable error/miss counts in bitrate_kbps, codec, duration_s, and packaged_at. A row can have the correct identity but still lose credit across several normalized columns.

### What to change

- Parse units explicitly; do not extract the first integer and assume its unit.
- Normalize codec families and recognized tags to the required contract.
- Convert duration milliseconds, timecodes, and ISO durations to seconds.
- Distinguish epoch seconds from milliseconds using a documented magnitude rule.
- Treat null sentinels and invalid values as missing, not real measurements.
- Test normalization functions independently with valid, invalid, and boundary values.

---

## 6. Reconcile equal timestamps instead of discarding complementary data

### Your code

~~~python
if existing is not None and row['packaged_at'] <= existing['packaged_at']:
    return []
~~~

### Gold code

The gold acceptance/merge logic compares candidates by key and package time, can merge complementary non-null values for the same instant, and handles conflicts deliberately instead of automatically discarding every equal-time record.

### Example input

~~~json
{"title_id":"T-0000001","variant":"720p","packaged_at":"2026-09-01T10:00:00Z","codec":"h264","bitrate":null}
{"title_id":"T-0000001","variant":"720p","packaged_at":"2026-09-01T10:00:00Z","codec":null,"bitrate":"2500 kbps"}
~~~

### Your behavior

The second row is discarded because its timestamp equals the stored timestamp. Its bitrate information is lost.

### Gold behavior

The merge path can fill a missing field from the same-time candidate while preserving known values and treating conflicts explicitly.

### Why it matters

Feeds can repeat or partially enrich a logical record. A timestamp-only tie-break can throw away useful fields even when the records represent the same package event.

### What to change

Define explicit candidate rules: newer package time wins; equal-time candidates fill missing fields; conflicting non-null values follow a deterministic policy. Keep duplicate handling separate from output emission.

---

## Recommended pattern skeleton

~~~python
class Handler:
    def __init__(self):
        self.held = {}             # (title_id, rendition) -> best row
        self.jobs = {}             # job_id -> accumulated job context
        self.pending_outputs = {}  # job_id -> outputs awaiting context

    def process(self, raw: str) -> list[dict]:
        # Parse, flatten, expand, normalize, and merge into held state.
        # Update job context or queue outputs if needed.
        # NEVER emit final rows here.
        return []

    def finalize(self) -> list[dict]:
        # Resolve pending outputs using available job context.
        # Merge resolved rows into held state.
        # Return one final row per (title_id, rendition).
        return list(self.held.values())
~~~

## Main lesson

Your solution handles many common aliases and normalizations, and the score/rank shows that the core approach works on much of the stream. The biggest architectural improvement is to **treat the input as an event stream that builds final state**, rather than as independent rows emitted as soon as they parse. Then improve recovery and normalization against the README's named feed conditions.

---

# Rerun update — Week 2 — The Manifest: complete before/after code

The handler emits candidate rows immediately while also maintaining a final candidate map. That lets older and newer versions of the same rendition both escape. The implementation also lacks complete job-close context reconciliation and equal-time field merging.

## Code before — exact current handler.py

The following is the complete handler snapshot fetched for this rerun, included verbatim as the before reference.

```python
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
```

## Code after — proposed change

```python
class Handler:
    def __init__(self):
        self.held = {}  # (title_id, rendition) -> winning compact row
        self.jobs = {}  # job_id -> (context, pending outputs)

    def process(self, raw: str) -> list[dict]:
        try:
            value = _parse(raw)
            for rec in _expand(value):
                try:
                    self._process_record(rec)
                except (ValueError, TypeError, OverflowError,
                        InvalidOperation, RecursionError):
                    continue
        except (ValueError, TypeError, OverflowError,
                InvalidOperation, RecursionError):
            pass
        return []

    def finalize(self) -> list[dict]:
        for context, pending in self.jobs.values():
            for rec in pending:
                try:
                    self._accept(_inherit(rec, context))
                except (ValueError, TypeError, OverflowError,
                        InvalidOperation, RecursionError):
                    continue
        self.jobs.clear()
        out = []
        for key in list(self.held):
            instant, row = self.held.pop(key)
            out.append(dict(zip(
                ('title_id', 'rendition', 'codec', 'bitrate_kbps',
                 'duration_s', 'packaged_at'),
                (None if cell is _CONFLICT else cell for cell in row),
            )))
        return out
```

This follows the reference lifecycle and state shape, but depends on the matching reference helpers (_parse, _expand, _process_record, _accept, _inherit) and constants. Bring them across as a consistent unit rather than copying only these methods.

Validation: process() always returns []; one final row per (title_id, rendition); close records complete pending outputs; newer package runs beat older re-deliveries; equal-time complementary fields merge; test rendition objects, codec tags, bps/Mbps/k units, duration formats, and epoch milliseconds.

## Learning notes

- The README's score, row counts, and named stream conditions are evidence; root-cause prioritization is an engineering assessment unless controlled tests prove it.
- Make one architectural change at a time, then compare exact output values and row counts against the task contract.
- Do not treat a proposal as drop-in code until all referenced helpers, constants, and dependencies are present and the full challenge test passes.
- Keep memory, identity/deduplication, event-time ordering, status precedence, and output lifecycle as separate invariants; optimizing one must not silently break another.
