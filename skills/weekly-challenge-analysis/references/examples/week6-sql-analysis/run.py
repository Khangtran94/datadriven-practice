"""Run a Week 6 DAG file night by night (landing windows + incremental merge), in SQLite or Postgres.
usage: python3 run.py            (uses SEEDS env, default 7)
"""
import os, re, sys, sqlite3, decimal
from gen import gen, COLS

REPO = '/home/claude/repo/weekly/week-06-the-dwell'
NIGHTS = 30

GOLD_HIST = {'unit_visit_history': ['src_key'], 'tariff_rate_history': ['tariff_cd', 'eff_date'],
             'line_operator_history': ['line_scac', 'snap_day']}
USER_HIST = {'unit_visit_history': ['rk'], 'tariff_rate_history': ['rk'], 'line_operator_history': ['rk']}
GOLD_FINAL = ['visits_latest', 'visit_days', 'tariff_day_rates', 'visit_charges', 'visit_lines', 'storage_charges']
USER_FINAL = ['storage_charges']


def split_tasks(path):
    text = open(path).read()
    parts = re.split(r'^-- task: (\w+)\s*$', text, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}


def render(sql, incremental, this):
    def keep(m):
        return m.group(1) if incremental else ''
    sql = re.sub(r'\{%\s*if is_incremental\(\)\s*%\}(.*?)\{%\s*endif\s*%\}', keep, sql, flags=re.S)
    sql = sql.replace('{{ this }}', this)
    return sql.strip().rstrip(';').strip()


class SQLiteEng:
    ph = '?'
    def __init__(self):
        self.c = sqlite3.connect(':memory:')
    def exec(self, sql, args=()):
        cur = self.c.execute(sql, args); return cur
    def rows(self, sql):
        cur = self.c.execute(sql); return [tuple(r) for r in cur.fetchall()], [d[0] for d in cur.description]
    def reset_raw(self, name, cols, rows):
        self.c.execute('DROP TABLE IF EXISTS %s' % name)
        self.c.execute('CREATE TABLE %s (%s)' % (name, ', '.join('"%s" TEXT' % c for c in cols)))
        self.c.executemany('INSERT INTO %s VALUES (%s)' % (name, ','.join('?' * len(cols))), rows)
    def drop(self, name):
        self.c.execute('DROP TABLE IF EXISTS %s' % name)
    def exists(self, name):
        return self.c.execute("select 1 from sqlite_master where name=?", (name,)).fetchone() is not None
    def delete_in(self, tbl, new, keys):
        k = ', '.join(keys)
        self.c.execute('DELETE FROM %s WHERE (%s) IN (SELECT %s FROM %s)' % (tbl, k, k, new))
    def commit(self): self.c.commit()


class PGEng:
    ph = '%s'
    def __init__(self, schema='w6'):
        import psycopg2
        self.c = psycopg2.connect(host='127.0.0.1', user='claude', dbname='dwell')
        self.c.autocommit = True
        self.cur = self.c.cursor()
        self.cur.execute('DROP SCHEMA IF EXISTS %s CASCADE' % schema)
        self.cur.execute('CREATE SCHEMA %s' % schema)
        self.cur.execute('SET search_path TO %s' % schema)
    def exec(self, sql, args=()):
        self.cur.execute(sql, args or None); return self.cur
    def rows(self, sql):
        self.cur.execute(sql); return [tuple(r) for r in self.cur.fetchall()], [d[0] for d in self.cur.description]
    def reset_raw(self, name, cols, rows):
        self.cur.execute('DROP TABLE IF EXISTS %s' % name)
        self.cur.execute('CREATE TABLE %s (%s)' % (name, ', '.join('"%s" TEXT' % c for c in cols)))
        if rows:
            import psycopg2.extras
            psycopg2.extras.execute_values(self.cur, 'INSERT INTO %s VALUES %%s' % name, rows)
    def drop(self, name):
        self.cur.execute('DROP TABLE IF EXISTS %s' % name)
    def exists(self, name):
        self.cur.execute("select to_regclass(%s)", (name,)); return self.cur.fetchone()[0] is not None
    def delete_in(self, tbl, new, keys):
        cond = ' AND '.join('%s.%s = %s.%s' % (tbl, k, new, k) for k in keys)
        self.cur.execute('DELETE FROM %s USING %s WHERE %s' % (tbl, new, cond))
    def commit(self): pass


def landing(night, uv, tr, lo):
    u = [r for r in uv if night - 6 <= r['night'] <= night]
    t = [r for r in tr if (night - 1 <= r['night'] <= night)] if night > 0 else [r for r in tr if r['night'] == 0]
    l = [r for r in lo if r['night'] == night]
    return u, t, l


def run_dag(eng, path, hist, final, uv, tr, lo, verbose=False):
    tasks = split_tasks(path)
    for n in range(NIGHTS):
        u, t, l = landing(n, uv, tr, lo)
        for name, rows in (('unit_visit', u), ('tariff_rate', t), ('line_operator', l)):
            cols = COLS[name]
            eng.reset_raw(name, cols, [tuple(r[c] for c in cols) for r in rows])
        for task, keys in hist.items():
            inc = eng.exists(task)
            sql = render(tasks[task], inc, task)
            if not inc:
                eng.exec('CREATE TABLE %s AS %s' % (task, sql))
            else:
                eng.drop('new_rows')
                eng.exec('CREATE TABLE new_rows AS %s' % sql)
                eng.delete_in(task, 'new_rows', keys)
                eng.exec('INSERT INTO %s SELECT * FROM new_rows' % task)
        eng.commit()
    for task in final:
        eng.drop(task)
        eng.exec('CREATE TABLE %s AS %s' % (task, render(tasks[task], False, task)))
    out = {}
    for task in list(hist) + final:
        out[task] = eng.rows('SELECT * FROM %s' % task)
    return out


def norm(v):
    if v is None: return None
    if isinstance(v, (int, float, decimal.Decimal)): return round(float(v), 6)
    return str(v)


def compare(a, b, table, key_cols, skip=()):
    """a, b = (rows, cols). Compare per key and per column, return stats."""
    ra, ca = a; rb, cb = b
    cols = [c for c in ca if c in cb and c not in skip]
    ia = [ca.index(c) for c in cols]; ib = [cb.index(c) for c in cols]
    ka = [cols.index(k) for k in key_cols]
    da, db = {}, {}
    for r in ra: da.setdefault(tuple(norm(r[i]) for i in ia)[:0] or tuple(norm(r[ia[j]]) for j in ka), []).append(tuple(norm(r[i]) for i in ia))
    for r in rb: db.setdefault(tuple(norm(r[ib[j]]) for j in ka), []).append(tuple(norm(r[i]) for i in ib))
    only_a = [k for k in da if k not in db]; only_b = [k for k in db if k not in da]
    mism = {c: 0 for c in cols}
    both = 0
    examples = []
    for k in da:
        if k in db:
            both += 1
            x, y = sorted(da[k], key=str)[0], sorted(db[k], key=str)[0]
            for j, c in enumerate(cols):
                if x[j] != y[j]:
                    mism[c] += 1
                    if len(examples) < 4: examples.append((k, c, x[j], y[j]))
    return dict(table=table, rows_a=len(ra), rows_b=len(rb), only_a=len(only_a), only_b=len(only_b), both=both,
               mismatches={c: n for c, n in mism.items() if n}, examples=examples)


if __name__ == '__main__':
    mode = sys.argv[1]  # gold | user | pg
    seed = int(os.environ.get('SEED', '7'))
    uv, tr, lo = gen(seed)
    if mode == 'gold':
        res = run_dag(SQLiteEng(), REPO + '/gold_submit.sql', GOLD_HIST, GOLD_FINAL, uv, tr, lo)
    elif mode == 'user':
        res = run_dag(SQLiteEng(), REPO + '/dag.sql', USER_HIST, USER_FINAL, uv, tr, lo)
    else:
        res = run_dag(PGEng(), sys.argv[2], GOLD_HIST, GOLD_FINAL, uv, tr, lo)
    for k, (rows, cols) in res.items(): print(k, len(rows))
