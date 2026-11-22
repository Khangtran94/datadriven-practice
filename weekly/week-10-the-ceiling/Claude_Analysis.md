# Week 10: The Ceiling: handler.py vs gold_submit.py

Score 0.8185, rank #4/6, +20 điểm, recovered 801,178/855,838, work per record 1.4x, 468 statements `[measured]`.

Chú thích tag: `[measured]` từ README, `[inferred]` từ đọc code, `[estimate]` từ test local trên dữ liệu giả (synthetic), `[not available]` code không có trong repo, `[untested]` chưa chạy.

## Vì sao điểm không cao hơn

60,340 dòng là bản thứ hai của một key đã emit và 9,855 dòng không khớp bản ghi nào, tổng mất 140,390 điểm `[measured]`. Chia ra thì 60,340 × 2 = 120,680 và 9,855 × 2 = 19,710. Tỉ lệ 2 điểm mỗi dòng giống Week 1 (854,938 dòng → 1,709,876 điểm). Vậy **86% điểm bị mất đến từ 1 lỗi: `process()` emit lại khi giá trị đổi**. Phần còn lại là bulletin heading làm sai station.

## Bảng xếp hạng tác động

| # | Vùng | Mất mát | Gold |
|---|---|---|---|
| 1 | Emit mỗi lần giá trị đổi | 60,340 dòng = 120,680 điểm `[measured]` | `process()` trả `[]`, chỉ emit ở `finalize()` |
| 2 | Bulletin heading → sai station | 9,855 dòng = 19,710 điểm `[measured]`, nguyên nhân `[inferred]` | Cắt heading trước khi đọc station |
| 3 | Giá trị gõ tay, đơn vị lạ | `visibility_m` sai 38,436; `altimeter_hpa` thiếu 187,860 `[measured]` | Chuẩn hóa token, nhiều dạng đơn vị |
| 4 | Giờ không có Z | 2.9% stream, recovered 0% `[measured]` | `_HEAD` nhận giờ không Z |
| 5 | Report bị cắt thành 2 dòng log | 6.0%, recovered 70% `[measured]` | `pending` nối dòng tiếp theo |
| 6 | Dấu trừ và số thiếu số 0 | 6.5%, recovered 72% `[measured]` | `_number_ratio` nhận `-`, `M`, 1 chữ số |

## 1. Emit mỗi lần giá trị đổi

**Dòng của bạn:** 660-672 và 697-698. **Dòng của gold:** `process` kết thúc ở 427 với `return []`, `finalize` ở 429-446.

**Ví dụ:** cùng `(EGLL, 2025-12-31T18:50Z)` đến 2 lần. Bản cũ có wind 12, bản "sent again with a fix" có wind 5.

- **Bạn:** lần 1 emit wind 12. Lần 2 giá trị khác nên emit thêm 1 dòng. Cùng key có 2 dòng, dòng thứ hai bị phạt 2 điểm.
- **Gold:** giữ bản cuối trong `held`, chỉ emit 1 dòng khi `finalize()`.

**Before** (`handler.py` 660-672, 697-698):

```python
        out = []
        for row in extracted:
            if not isinstance(row, dict):
                continue
            key = _record_key(row)
            if key is None:
                continue
            values = _pack_record(row)
            if self.records_map.get(key) == values:
                continue
            self.records_map[key] = values
            out.append(row)
        return out
...
    def finalize(self):
        return []
```

**After:**

```python
        for row in extracted:
            if not isinstance(row, dict):
                continue
            key = _record_key(row)
            if key is None:
                continue
            self.records_map[key] = _pack_record(row)   # bản log sau cùng thắng
        return []
...
    def finalize(self):
        return self.extract_columns()   # 1 dòng cho mỗi key
```

**How it works:** README nói "the copy logged last still stands". Vì vậy không cần emit sớm. Bạn cứ ghi đè vào `records_map`, đến cuối mới trả mỗi key đúng 1 lần. Giống như viết biên bản họp: chờ họp xong rồi ghi 1 lần, thay vì ghi mỗi khi có người đổi ý. Hàm `extract_columns()` và `_unpack_record` đã có sẵn trong file của bạn nên không cần viết mới.

**Proof** `[estimate]`: dữ liệu giả 17,401 key (3 seed). Bản gốc phát ra 1,039 dòng trùng, bản sửa còn 0.

## 2. Bulletin heading làm sai station

**Dòng của bạn:** 244-248. **Gold:** `_BULLETIN` ở 19-23 và `_header` ở 109-139.

**Ví dụ:** `SAUS70 KWBC 311900 KJFK 311853Z 18012KT ...` (không có chữ METAR).

- **Bạn:** nhận `KWBC` làm station. Observed time vẫn đúng nên ra 1 key không tồn tại trong đáp án. Đây là kiểu "matched no record" `[inferred]`.
- **Gold:** cắt heading, ra `KJFK`. Đã chạy cả 2 handler trên dòng này và xác nhận kết quả `[estimate]`.

**Before** (244-248):

```python
    for token in tokens:
        if OBSERVATION_TIME_RE.fullmatch(token):
            break
        if token != "AUTO" and ICAO_RE.fullmatch(token):
            return token
```

**After:** thêm vào đầu `tidy()` (hàm mới ở mục 3), chạy 1 lần trước mọi extractor.

```python
BULLETIN_RE = r"^(?:ZCZC[^\n]*\n\s*)?(?:\d{3}\s+)?[A-Z]{4}\d{2}\s+[A-Z]{4}\s+\d{6}(?:\s+(?:CC|RR|AA)[A-Z])?\s+"
t = re.sub(BULLETIN_RE, "", str(report).strip().upper())
```

**How it works:** heading luôn có dạng 6 ký tự (loại dữ liệu + số) + 4 chữ cái (trung tâm) + 6 chữ số (giờ). Nhận dạng đúng mẫu đó rồi bỏ đi, chỉ giữ phần report của sân bay.

**Proof** `[estimate]`: unmatched 482 → 0, recovered 92.1% → 94.9% khi chỉ áp dụng sửa này.

## 3. Giá trị gõ tay và đơn vị lạ

**Dòng của bạn:** `WIND_RE` 30-33, visibility 393, altimeter 493 và 504. **Gold:** `_WIND` 25 (nhận `KTS`, `KPH`), `_METRES` 27, `_ALTIMETER_TYPED` 33, `_pressure` 189-206.

**Ví dụ:** `180/12KT`, `30007 KT`, `10 SM`, `BKN 015`, `22 / 14`, `A 3001`, `18012KTS`, `10KM`, `QNH1013`, `1013HPA`, `A30.01`, `A3O01`, `9999NDV R27L/0800`.

- **Bạn:** `WIND_RE` yêu cầu đúng `KT|MPS|KMH` dính liền. `\bA(\d{4})\b` không nhận `A30.01`. Dòng 393 coi mọi token 4-5 chữ số là visibility, nên `3001` sau nhiệt độ bị đọc là 3001 m.
- **Gold:** nhận cả các dạng trên.

**Before** (30-33, 393, 493, 504):

```python
WIND_RE = re.compile(
    r"(?:^|\s)(?:[0-9]{3}|VRB)([0-9]{2,3})"
    r"(?:G[0-9]{2,3})?(KT|MPS|KMH)(?:\s|=|$)"
)
...
            if re.fullmatch(r"\d{4,5}", token) and not token.startswith("R"):
...
        a_match = re.search(r"\bA(\d{4})\b", body)
...
        q_match = re.search(r"\bQ(\d{4})\b", body)
```

**After:** hàm `tidy(report)` viết lại mọi dạng gõ tay về dạng chuẩn 1 lần, các extractor cũ giữ nguyên:

```python
def tidy(report):
    t = re.sub(BULLETIN_RE, "", str(report).strip().upper())
    t = re.sub(r"\s+", " ", t).strip()
    t = re.sub(r"\b(\d{3}|VRB)/(\d{2,3})(G\d{2,3})? ?(KTS?|MPS|KMH)\b", r"\1\2\3\4", t)  # 180/12KT
    t = re.sub(r"\b((?:\d{3}|VRB)\d{2,3}(?:G\d{2,3})?) (KTS?|MPS|KMH)\b", r"\1\2", t)     # 30007 KT
    t = re.sub(r"\b((?:\d{3}|VRB)\d{2,3}(?:G\d{2,3})?)KTS\b", r"\1KT", t)                 # KTS -> KT
    t = re.sub(r"\b(\d+) SM\b", r"\1SM", t)                                                # 10 SM
    t = re.sub(r"\b(BKN|OVC|FEW|SCT|VV) (\d{3})", r"\1\2", t)                              # BKN 015
    t = re.sub(r"\bA (\d{4})\b", r"A\1", t)                                                # A 3001
    t = re.sub(r"\bQNH ?(\d{4})\b", r"Q\1", t)                                             # QNH1013
    t = re.sub(r"\b(\d{4}) ?HPA\b", r"Q\1", t)                                             # 1013HPA
    t = re.sub(r"\bA(\d{2})[.,](\d{2})\b", r"A\1\2", t)                                    # A30.01
    t = re.sub(r"\b(\d{4})NDV\b", r"\1", t)                                                # 9999NDV
    t = re.sub(r"\bR\d{2}[LCR]?/\S+ ?", "", t)                                             # R27L/0800
    return t
```

Gọi nó đầu `extract_columns`: `row = dict(row, report=tidy(row.get("report")))`. Cũng thêm bước đổi `KM` ra mét, sửa chữ O gõ thay số 0 (`A3O01`, `BKNO15`), và nhận 4 chữ số trần sau nhiệt độ thành `A`/`Q` theo khoảng giá trị (2800-3200 là inch, 850-1100 là hPa).

**How it works:** thay vì dạy từng extractor hiểu mọi kiểu gõ, bạn "làm sạch chính tả" một lần ở cửa vào. Sau đó mọi regex cũ thấy đúng dạng chuẩn. Muốn thêm kiểu gõ mới chỉ cần thêm 1 dòng vào `tidy()`.

**Proof** `[estimate]` (từng sửa riêng, trên bản gốc): sửa dạng wind/cloud/SM làm wind 78.4% → 90.1%. Sửa đơn vị làm altimeter 74.0% → 84.0% và visibility 71.2% → 76.5%.

## 4. Giờ không có chữ Z

**Dòng của bạn:** 36 và 524. **Gold:** `_HEAD` 11, `Z?` là tùy chọn.

**Ví dụ:** `METAR EGLL 311851 ...` hoặc `311851UTC`.

- **Bạn:** cả `OBSERVATION_TIME_RE` (dòng 36) và regex ở dòng 524 đều bắt buộc chữ Z, nên không tìm được giờ và bỏ cả dòng. README đo được 0% `[measured]`.
- **Gold:** nhận giờ không Z.

**Before:**

```python
OBSERVATION_TIME_RE = re.compile(r"^\d{6}Z$")
...
    timestamp_match = re.search(r"\b(\d{2})(\d{2})(\d{2})Z\b", body)
```

**After:** thêm vào `tidy()`, tự gắn Z cho giờ đứng ngay sau station:

```python
t = re.sub(r"\b((?:METAR|SPECI)(?: COR)? [A-Z]{4} \d{6})(?:UTC)?\b",
           lambda m: m.group(1) + "Z", t)
```

**How it works:** mọi report đều là UTC (README nói rõ), nên Z chỉ là chữ ký. Thêm Z cho chuẩn thì 2 regex cũ chạy bình thường.

**Proof** `[estimate]`: recovered 92.1% → 97.0%. Số dòng trùng tăng (1,039 → 1,093) vì nhận được thêm key, và sửa ở mục 1 xử lý đúng phần này. Chỉ test dạng có `METAR`/`SPECI` đứng trước. Dạng không có chữ này `[untested]`.

## 5. Report bị cắt thành 2 dòng log

**Dòng của bạn:** 653-658, mỗi dòng log xử lý riêng. **Gold:** `pending` ở 378-379, `_continued_body` 356-373, xử lý trong `process` 404-417.

**Ví dụ:** dòng 1 `METAR LIRF 290151Z 21003KT 1500 OVC067`, dòng 2 `      -10/-12 Q1013=` (bắt đầu bằng khoảng trắng, không có station).

- **Bạn:** dòng 1 chỉ có wind/visibility/ceiling, thiếu temp và altimeter. Dòng 2 không có station nên bị bỏ.
- **Gold:** giữ dòng 1 ở `pending`, nối dòng 2 vào, rồi mới parse.

**After** (rút gọn):

```python
    def _flush(self):
        if self.pending is None:
            return
        held, self.pending = self.pending, None
        rows = [r for r in (normalize_row(held),) if r is not None]
        for row in extract_columns(rows):
            key = _record_key(row)
            if key is not None:
                self.records_map[key] = _pack_record(row)

    def process(self, raw):
        try:
            rows = rows_from_value(parse_raw(raw) or [])
        except (TypeError, ValueError, json.JSONDecodeError, UnicodeDecodeError):
            self._flush(); return []
        for row in rows:
            canon = to_canonical(row)
            report = canon["report"]
            if not isinstance(report, str):
                continue
            if report[:1].isspace() and self.pending is not None:   # nửa sau của report
                self.pending["report"] += " " + report.strip()
                continue
            self._flush()
            self.pending = dict(canon)
        return []

    def finalize(self):
        self._flush()
        return self.extract_columns()
```

**How it works:** mỗi report được giữ lại chờ dòng kế tiếp. Dòng kế tiếp bắt đầu bằng khoảng trắng nghĩa là nó là phần đuôi, thì nối vào. Nếu không thì report cũ đã trọn vẹn, đẩy vào bảng rồi giữ report mới. Điểm quan trọng là `clean_report` (dòng 222) xóa khoảng trắng đầu dòng, nên phải kiểm tra khoảng trắng đó **trước** khi làm sạch.

**Proof** `[estimate]`: sửa riêng thì temp 80.9% → 86.3%, altimeter 74.0% → 79.1%, wind 78.4% → 80.1%.

## 6. Dấu trừ và số thiếu số 0

**Dòng của bạn:** 466. **Gold:** `_TEMP` 29-30 và `_number_ratio` 153-156.

**Ví dụ:** `-5/-10`, `M5/M1`, `5/M1`. Bản chuẩn là `M05/M10`.

**Before:**

```python
        standard_match = re.search(r"\b(M?\d{2})/(M?\d{2})\b", body)
```

**After:** thêm vào `tidy()`, đổi mọi dạng về `M05/M10`:

```python
_TTOK = re.compile(r"^([M-]?)(\d{1,2})/([M-]?)(\d{1,2})$")
def _temp_tok(tok):
    m = _TTOK.match(tok)
    if not m:
        return tok
    a, x, b, y = m.groups()
    return f"{'M' if a else ''}{int(x):02d}/{'M' if b else ''}{int(y):02d}"
# trong tidy():  t = " ".join(_temp_tok(tok) for tok in t.split(" "))
```

**Proof** `[estimate]`: temp 80.9% → 82.6% khi sửa riêng. Dạng `-3 / -10` (vừa có dấu trừ vừa có khoảng trắng) vẫn còn sót 5 dòng trên 5,783.

## Tổng kết test

Dữ liệu giả sinh từ các điều kiện trong README (3 seed, tổng 17,401 key, 5 cột như bảng của bạn), chạy bản của bạn, gold, và bản của bạn đã áp dụng cả 6 sửa `[estimate]`:

| | recovered | unmatched | dòng trùng | wind | vis | ceiling | temp | altimeter |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Bạn (gốc) | 92.1% | 482 | 1,039 | 78.4% | 71.2% | 87.9% | 80.9% | 74.0% |
| Gold | 96.1% | 0 | 0 | 90.2% | 87.5% | 93.6% | 91.7% | 87.8% |
| Bạn + 6 sửa | 99.9% | 0 | 0 | 99.9% | 99.8% | 99.9% | 99.8% | 99.1% |

Đừng đọc bảng này như điểm dự đoán. Generator và các sửa đều viết từ cùng một bản đọc README, nên bản sửa nhìn đẹp hơn gold. Gold phải đối mặt với dữ liệu thật có nhiều kiểu hơn. Con số đáng tin nhất là **dòng trùng 1,039 → 0**, vì nó khớp với lỗi đo thật trong README.

## Điểm mạnh của handler bạn so với gold

Handler của bạn đọc được dòng relay (`msg`, `src`, `ts`) qua `ALIASES` và `flatten` (dòng 8-21, 173-216), còn gold chỉ tìm `report`, `rawOb`, `metar`, `raw_text`, `line` (dòng 322-324) `[inferred]`. Bạn cũng recover được JSON bị bọc nhiều lớp chuỗi (dòng 151-159).

## Không so sánh được hoặc chưa kiểm chứng

- **`2400` (giờ 24):** cả 2 handler trả `[]` `[estimate]`. Đây là 0.2% stream.
- **`CALM`:** cả 2 trả `wind_kt = None`. README không nói đáp án nên không đánh giá.
- **Nhiệt độ thập phân `22.4/14.1`:** `[untested]`.
- **Bulletin có `ZCZC` hoặc xuống dòng giữa heading:** `[untested]`.
- **TEMPO/BECMG, VV, MPS:** handler bạn đã xử lý (dòng 391-433), không đưa vào phần sửa.

## Mẫu nên dùng cho các tuần sau

```python
class Handler:
    def __init__(self):
        self.rows = {}        # key -> giá trị cuối cùng
        self.pending = None   # report đang chờ dòng nối
    def process(self, raw):
        ...                   # chỉ ghi vào self.rows
        return []
    def finalize(self):
        self._flush()
        return [unpack(k, v) for k, v in self.rows.items()]
```

Quy tắc: **không bao giờ emit cùng một key từ `process` rồi lại emit ở `finalize`**, và không emit lại khi giá trị đổi. Week 1 mất 1,709,876 điểm vì lý do này, week 10 mất 120,680.
