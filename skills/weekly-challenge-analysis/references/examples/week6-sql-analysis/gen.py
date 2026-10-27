"""Synthetic Week 6 (The Dwell) raw data built from the README conditions.
All columns are TEXT. Each row also carries a hidden 'night' (0..29) used only by the harness
to simulate the landing windows (unit_visit keeps 7 nights, tariff_rate 2, line_operator 1).
"""
import random, json, os
from datetime import datetime, timedelta, timezone

START = datetime(2026, 9, 25, tzinfo=timezone.utc)
NIGHTS = 30
NULLS = ['', 'NULL', '\\N', 'None', 'NaN', 'N/A', '-']


def night_date(n):
    return (START + timedelta(days=n)).strftime('%Y-%m-%d')


def fmt(ts, style, rnd):
    """ts is an aware UTC datetime. Returns text in one of the README's formats."""
    if style == 0: return ts.strftime('%Y-%m-%dT%H:%M:%SZ')
    if style == 1: return ts.strftime('%Y-%m-%dT%H:%M:%S+00:00')
    if style == 2: return ts.strftime('%Y-%m-%dT%H:%M:%S.') + '%03dZ' % rnd.randint(0, 999)
    if style == 3: return str(int(ts.timestamp()))
    if style == 4: return str(int(ts.timestamp()) * 1000)
    off = rnd.choice([(5, 30), (8, 0), (-5, 0), (1, 0), (9, 0)])
    loc = ts + timedelta(hours=off[0], minutes=(off[1] if off[0] >= 0 else -off[1]))
    sign = '+' if off[0] >= 0 else '-'
    hh, mm = abs(off[0]), off[1]
    base = loc.strftime('%Y-%m-%dT%H:%M:%S')
    if style == 5: return base + '%s%02d:%02d' % (sign, hh, mm)
    if style == 6: return base.replace('T', ' ') + '%s%02d%02d' % (sign, hh, mm)
    if style == 7:
        if mm: return base + '%s%02d:%02d' % (sign, hh, mm)
        return base.replace('T', ' ') + '%s%02d' % (sign, hh)
    if style == 8: return ts.strftime('%Y-%m-%d %H:%M:%S') + ' UTC'
    if style == 9:  # wall clock at the port (UTC+8), no zone
        return (ts + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M:%S')
    raise ValueError(style)


def gen(seed=7, n_visits=700):
    rnd = random.Random(seed)
    lines = ['MAEU', 'MSCU', 'CMDU', 'HLCU', 'ONEY', 'EGLV', 'COSU', 'ZIMU', 'OOLU', 'YMLU']
    tariffs = ['STD1', 'STD2', 'REEF', 'HAZ1', 'OOG1']

    # ---- tariff_rate ------------------------------------------------------------
    tariff_rows = []
    cur_rate = {}
    for t in tariffs:
        cur_rate[t] = rnd.choice([10.0, 12.5, 15.25, 8.75, 20.0])
        for off, rate in [(-60, cur_rate[t])]:
            pass
    base_eff = datetime(2026, 8, 1, tzinfo=timezone.utc)

    def rate_text(r):
        s = '%.2f' % r if rnd.random() < 0.7 else '%.4f' % r
        k = rnd.random()
        if os.environ.get('RATE_FMT') == 'messy':   # extra shapes NOT in the README; used only to stress the Postgres port
            if k < 0.07: return s.replace('.', ',')
            if k < 0.12: return '$' + s
        if k < 0.15: return rnd.choice(NULLS)
        return s

    def stamp(n, style=None):
        t = START + timedelta(days=n, hours=rnd.randint(1, 2), minutes=rnd.randint(0, 59))
        return fmt(t, style if style is not None else rnd.choice([0, 0, 0, 1, 3, 4]), rnd)

    for t in tariffs:
        tariff_rows.append(dict(night=0, tariff_cd=t, eff_date=base_eff.strftime('%Y-%m-%d'),
                                rate_usd=rate_text(cur_rate[t]), _batch_id=night_date(0), _loaded_at=stamp(0)))
        # a few changes during the period
        for _ in range(rnd.randint(1, 3)):
            n = rnd.randint(1, NIGHTS - 2)
            new = round(cur_rate[t] * rnd.choice([0.9, 1.1, 1.2, 0.8]), 2)
            eff = START + timedelta(days=rnd.randint(max(0, n - 3), n + 6))
            tariff_rows.append(dict(night=n, tariff_cd=rnd.choice([t, t.lower(), ' ' + t + ' ']),
                                    eff_date=eff.strftime('%Y-%m-%d'), rate_usd=rate_text(new),
                                    _batch_id=night_date(n), _loaded_at=stamp(n)))
            # sometimes the same effective day is published wrong first, then corrected later
            if rnd.random() < 0.4 and n + 1 < NIGHTS:
                tariff_rows.append(dict(night=n + 1, tariff_cd=t, eff_date=eff.strftime('%Y-%m-%d'),
                                        rate_usd=rate_text(new + 1.0), _batch_id=night_date(n + 1),
                                        _loaded_at=stamp(n + 1)))

    # ---- line_operator ----------------------------------------------------------
    line_rows = []
    state = {}
    for l in lines:
        state[l] = dict(bill_to='P%05d' % rnd.randint(1, 99999), test=rnd.random() < 0.15,
                        change_at=rnd.choice([None, rnd.randint(5, 25)]), gone_at=rnd.choice([None, None, None, rnd.randint(10, 28)]),
                        test_off=rnd.choice([None, rnd.randint(3, 15)]))
        if state[l]['test_off'] is not None: state[l]['test'] = True
    empty_nights = set(rnd.sample(range(1, NIGHTS), 3))
    for n in range(NIGHTS):
        if n in empty_nights: continue
        for l in lines:
            s = state[l]
            if s['gone_at'] is not None and n >= s['gone_at']: continue
            if s['change_at'] is not None and n == s['change_at']: s['bill_to'] = 'P%05d' % rnd.randint(1, 99999)
            if s['test_off'] is not None and n == s['test_off']: s['test'] = False
            code = rnd.choice([l, l, l, l.lower(), ' ' + l + ' ', l.title()])
            bt = s['bill_to'] if rnd.random() > 0.05 else rnd.choice(NULLS)
            flag = ('Y' if s['test'] else 'N')
            if rnd.random() < 0.3: flag = rnd.choice(['yes', 'true', '1'] if s['test'] else ['no', 'false', '0', 'n'])
            if rnd.random() < 0.04: flag = rnd.choice(NULLS)
            line_rows.append(dict(night=n, line_scac=code, line_name=l + ' Lines', bill_to=bt, test_flag=flag,
                                  _batch_id=night_date(n), _loaded_at=stamp(n)))

    # ---- unit_visit ---------------------------------------------------------------
    uv = []
    state_words = {
        'discharged': ['discharged', 'Discharged', 'DISCH', 'unloaded', 'dischgd'],
        'held': ['held', 'On Hold', 'hold', 'HOLDING'],
        'gated_out': ['gated_out', 'Gate-Out', 'GATEOUT', 'exited', 'departed', 'out'],
        'transshipped': ['transshipped', 'TS', 'Transhipped', 'trans'],
    }

    def unit_text(u):
        k = rnd.random()
        if k < 0.6: return u
        if k < 0.75: return u[:4] + ' ' + u[4:]
        if k < 0.9: return (u[:4] + '-' + u[4:]).lower()
        return ' ' + u + ' '

    def gkey_text(g):
        k = rnd.random()
        if k < 0.84: return g
        if k < 0.88: return g + '.0'
        if k < 0.92: return ' ' + g + ' '
        if k < 0.96: return '00' + g
        return rnd.choice(NULLS)

    def remarks_text(ref):
        k = rnd.random()
        if ref is None:
            return rnd.choice([None, '{}', '{"note":"x"}', ''])
        if k < 0.55: return json.dumps({'booking_ref': ref, 'note': 'ok'})
        if k < 0.65: return json.dumps({'bookingRef': ref})
        if k < 0.75: return '{"booking_ref": "%s"' % ref[:rnd.randint(4, 9)]  # cut short
        if k < 0.8: return '{"booking_ref":"%s", "pad"' % ref  # cut short after the ref
        if k < 0.9: return json.dumps({'booking_ref': ref.replace('BK-', '')})
        return json.dumps({'booking_ref': rnd.choice(['', '-', 'N/A'])})

    used = set()
    for v in range(n_visits):
        while True:
            g = '%08d' % rnd.randint(10000000, 99999999)
            if g not in used: used.add(g); break
        unit = ''.join(rnd.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ') for _ in range(4)) + '%07d' % rnd.randint(0, 9999999)
        line = rnd.choice(lines)
        tcd = rnd.choice(tariffs)
        ref = ('BK-%07d' % rnd.randint(1, 9999999)) if rnd.random() < 0.8 else None
        dsch = START + timedelta(days=rnd.randint(-3, NIGHTS - 4), hours=rnd.randint(0, 23), minutes=rnd.randint(0, 59))
        first = max(0, (dsch.date() - START.date()).days)
        count = rnd.randint(1, 6)
        gate_idx = rnd.randint(0, count - 1) if rnd.random() < 0.65 else None
        gate_ts = None
        for i in range(count):
            n = first + i
            if n >= NIGHTS: break
            batch = night_date(n)
            upd = START + timedelta(days=n, hours=rnd.randint(0, 22), minutes=rnd.randint(0, 59))
            row = dict(night=n, visit_gkey=gkey_text(g), unit_nbr=unit_text(unit), line_scac=rnd.choice([line, line.lower(), ' ' + line]),
                       visit_state=rnd.choice(state_words['discharged'] if i == 0 else state_words['held'] if rnd.random() < .2 else state_words['discharged']),
                       tariff_cd=rnd.choice([tcd, tcd.lower()]), days_chg=rnd.choice(['1', '1', '1', '2', '0', '1.0', '-1']),
                       dsch_time=fmt(dsch, rnd.choice([0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]), rnd),
                       gate_out_time=rnd.choice(NULLS), last_upd_time=fmt(upd, rnd.choice([0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]), rnd),
                       remarks=remarks_text(ref), _batch_id=batch, _restated_day=None,
                       _loaded_at=fmt(upd + timedelta(hours=1), rnd.choice([0, 0, 1, 3, 4]), rnd))
            if gate_idx is not None and i == gate_idx:
                gate_ts = upd + timedelta(minutes=5)
                row['visit_state'] = rnd.choice(state_words['gated_out'])
                row['gate_out_time'] = fmt(gate_ts, rnd.choice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]), rnd)
                if rnd.random() < 0.5:  # gate app: only its own columns
                    for c in ('unit_nbr', 'line_scac', 'tariff_cd', 'days_chg', 'dsch_time', 'remarks'):
                        row[c] = rnd.choice(NULLS + [None])
            elif rnd.random() < 0.15:  # newest row missing fields
                row['visit_state'] = rnd.choice(NULLS + [None])
            if gate_ts is not None and i > gate_idx and rnd.random() < 0.5:
                row['gate_out_time'] = rnd.choice(NULLS)
            if rnd.random() < 0.12: row['last_upd_time'] = rnd.choice(NULLS)
            for c in ('unit_nbr', 'line_scac', 'tariff_cd', 'days_chg', 'dsch_time', 'remarks'):
                if rnd.random() < 0.05: row[c] = rnd.choice(NULLS + [None])
            uv.append(row)
            if rnd.random() < 0.10: uv.append(dict(row))  # same row twice in a batch
            if rnd.random() < 0.05 and i > 0:  # restated day: replaces the days of an earlier day
                r = dict(row)
                r['_restated_day'] = night_date(n - 1)
                r['days_chg'] = rnd.choice(['1', '2', '0', '3'])
                r['_batch_id'] = night_date(min(NIGHTS - 1, n + 1)); r['night'] = min(NIGHTS - 1, n + 1)
                uv.append(r)
            if rnd.random() < 0.05 and n + 2 < NIGHTS:  # old rows in a newer batch
                r = dict(row)
                r['_batch_id'] = night_date(n + 2); r['night'] = n + 2
                r['_loaded_at'] = fmt(START + timedelta(days=n + 2, hours=3), 0, rnd)
                uv.append(r)
            if rnd.random() < 0.06 and n + 1 < NIGHTS:  # arrives a night late
                uv[-1]['night'] = min(NIGHTS - 1, uv[-1]['night'] + 1)
    return uv, tariff_rows, line_rows


COLS = {
    'unit_visit': ['visit_gkey', 'unit_nbr', 'line_scac', 'visit_state', 'tariff_cd', 'days_chg', 'dsch_time',
                   'gate_out_time', 'last_upd_time', 'remarks', '_batch_id', '_restated_day', '_loaded_at'],
    'tariff_rate': ['tariff_cd', 'eff_date', 'rate_usd', '_batch_id', '_loaded_at'],
    'line_operator': ['line_scac', 'line_name', 'bill_to', 'test_flag', '_batch_id', '_loaded_at'],
}

if __name__ == '__main__':
    import sys
    uv, tr, lo = gen(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
    print(len(uv), len(tr), len(lo))
