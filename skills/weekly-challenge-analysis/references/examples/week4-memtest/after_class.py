# ------------------------------------------------------------------ handler
# Memory fix: keep a few packed bytes per (accession, test) key instead of one dict per line.
import struct

_PACK = struct.Struct("<qIBBIqqH")        # ts_us, seq, status, trunc, pid, value_cents, obs_s, unit_idx (36 bytes)
TS, SEQ, ST, TRUNC, PID, VAL, OBS, UNIT = range(8)
NO_TS, NO_PID, NO_NUM, NO_UNIT = -(1 << 62), 0xFFFFFFFF, -(1 << 62), 0xFFFF
S_NONE, S_PRELIM, S_W, S_FINAL, S_CORR, S_U = range(6)
ST_CODE = {None: S_NONE, "preliminary": S_PRELIM, "W": S_W, "final": S_FINAL,
           "corrected": S_CORR, "U": S_U}
ST_NAME = {v: k for k, v in ST_CODE.items()}
RANK_BY_CODE = (0, 1, 2, 3, 4, 0)         # same order as RANK in the original handler
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
ONE_US = timedelta(microseconds=1)


def _win_key(r):                          # same ordering the original _resolve used for the winner
    return (not r[TRUNC], RANK_BY_CODE[r[ST]], r[TS], r[SEQ])


def _resolve(items):
    """Same rules as the original Handler._resolve, on packed tuples."""
    items = sorted(items, key=lambda r: (r[TS], r[SEQ]))
    cands, last = [], None
    for e in items:
        if e[ST] == S_U:
            if e[VAL] != NO_NUM or last is None:
                c = e[:ST] + (S_FINAL,) + e[ST + 1:]
            elif last[ST] == S_PRELIM:
                c = (e[TS], e[SEQ], S_FINAL) + last[TRUNC:]
            else:
                continue
            cands.append(c)
            last = c
            continue
        cands.append(e)
        if e[VAL] != NO_NUM and e[ST] != S_W:
            last = e
    return max(cands, key=_win_key) if cands else None


MAX_KEEP = 6                              # real keys have a few lines; beyond this we prune


def _reduce(items):
    """Keep what can still decide the answer for this key (all distinct entries while there are few)."""
    uniq = {}
    for r in items:                       # an exact re-send adds nothing: keep only its latest copy
        uniq[r[:SEQ] + r[SEQ + 1:]] = r
    items = list(uniq.values())
    if len(items) <= MAX_KEEP:
        return items
    keep = {}                             # many lines for one key: keep only the entries that can still matter
    plain = [r for r in items if r[ST] != S_U]
    if plain:                                                   # best candidate so far
        keep[max(plain, key=_win_key)] = 1
    valued = [r for r in plain if r[VAL] != NO_NUM and r[ST] != S_W]
    if valued:                                                  # latest result with a value (a U line inherits it)
        keep[max(valued, key=lambda r: (r[TS], r[SEQ]))] = 1
    for has_value in (True, False):                             # latest U line with / without a value
        us = [r for r in items if r[ST] == S_U and (r[VAL] != NO_NUM) == has_value]
        if us:
            keep[max(us, key=lambda r: (r[TS], r[SEQ]))] = 1
    return list(keep)


class Handler:
    def __init__(self):
        self.state = {}       # (accession, test) -> bytes: a few packed entries, never one per line
        self.units = []       # distinct unit strings, referenced by index
        self.unit_ix = {}
        self.merge = {}
        self.n = 0

    def _unit_index(self, u):
        if u is None:
            return NO_UNIT
        i = self.unit_ix.get(u)
        if i is None:
            i = self.unit_ix[u] = len(self.units)
            self.units.append(u)
        return i

    # -- parse one log line into (key, packed entry) or None.  Parsing logic is unchanged
    #    from the original; only the output form and the removal of the line fingerprint differ.
    def _parse(self, raw):
        ex = extract(raw)
        if ex is None:
            return None
        msg, trunc, conn = ex
        i = msg.find("MSH|")
        if i < 0:
            return None
        s = fix_layers(msg[i:])
        segs = split_segments(s)
        parsed, obxs = {}, []
        for k, seg in enumerate(segs):
            f = seg.lstrip("\ufeff \t").split("|")
            if trunc and k == len(segs) - 1:
                f = f[:-1]
            name = f[0].strip().upper() if f else ""
            if name == "OBX":
                obxs.append(f)
            elif name and name not in parsed:
                parsed[name] = f

        msh = parsed.get("MSH")
        if not msh or len(msh) < 11:
            return None
        if "ORU" not in g(msh, 8).upper():
            return None
        if g(msh, 10).split("^")[0].strip().upper() != "P":
            return None

        pid = pick_pid(parsed.get("PID"))

        mrg = parsed.get("MRG")
        if mrg and pid and not trunc:
            for old, a, _t in _cx(g(mrg, 1)):
                if re.fullmatch(r"\d{8}", old) and a in ("", "HOSP") and old != pid:
                    self.merge[old] = pid

        obr = parsed.get("OBR")
        if not obr or not obxs:
            return None
        acc = g(obr, 3).split("^")[0].strip().upper()
        if not re.fullmatch(r"[A-Z0-9][A-Z0-9_-]{2,31}", acc):
            return None

        obx, test, code = None, None, ""
        for f in obxs:
            comps = g(f, 3).split("^")
            c0 = comps[0].strip().upper()
            c3 = comps[3].strip().upper() if len(comps) > 3 else ""
            t = TEST_CODES.get(c0) or TEST_CODES.get(c3)
            if t:
                obx, test, code = f, t, c0
                break
        if obx is None:
            obx = obxs[0]
            code = g(obx, 3).split("^")[0].strip().upper()
            if not EMIT_UNMAPPED_TESTS:
                return None
            if not code:
                return None

        zone = sender_zone(g(msh, 2), g(msh, 3), acc)
        tok = g(obx, 11).split("^")[0].strip().upper()
        if not tok:
            tok = g(obr, 25).split("^")[0].strip().upper()
        st = STATUS_MAP.get(tok)

        val = None if st == "W" else parse_value(g(obx, 5), g(obx, 8)) if g(obx, 5) else None
        self.n += 1
        ts = parse_ts(g(msh, 6), zone)
        obs = parse_ts(g(obr, 7).split("^")[0], zone)
        rec = (
            (ts - EPOCH) // ONE_US if ts else NO_TS,
            self.n,
            ST_CODE[st],
            1 if trunc else 0,
            int(pid) if pid else NO_PID,
            int(val.replace(".", "")) if val is not None else NO_NUM,   # "95.20" -> 9520 cents
            int((obs - EPOCH).total_seconds()) if obs else NO_NUM,
            self._unit_index(norm_unit(g(obx, 6))),
        )
        return (acc, test), rec

    def process(self, raw):
        try:
            parsed = self._parse(raw)
            if parsed is not None:
                key, rec = parsed
                blob = self.state.get(key)
                items = list(_PACK.iter_unpack(blob)) if blob else []
                items.append(rec)
                self.state[key] = b"".join(_PACK.pack(*r) for r in _reduce(items))
        except Exception:
            pass
        return []                                 # everything is emitted once, in finalize()

    def _final_pid(self, p):
        if not APPLY_MERGES or p is None:
            return p
        seen = set()
        while p in self.merge and p not in seen:
            seen.add(p)
            p = self.merge[p]
        return p

    def finalize(self):
        rows, state, units = [], self.state, self.units
        while state:
            (acc, test), blob = state.popitem()   # free each key's state as its row is built
            w = _resolve(list(_PACK.iter_unpack(blob)))
            if w is None:
                continue
            pid = "%08d" % w[PID] if w[PID] != NO_PID else None
            val = "%d.%02d" % divmod(w[VAL], 100) if w[VAL] != NO_NUM else None
            obs = (EPOCH + timedelta(seconds=w[OBS])).strftime("%Y-%m-%dT%H:%M:%SZ") if w[OBS] != NO_NUM else None
            st = ST_NAME[w[ST]]
            rows.append({
                "accession": acc,
                "test": test,
                "patient_id": self._final_pid(pid),
                "value": val,
                "unit": units[w[UNIT]] if w[UNIT] != NO_UNIT else None,
                "observed_at": obs,
                "status": st if st in OUT_STATUS else None,
            })
        return rows
