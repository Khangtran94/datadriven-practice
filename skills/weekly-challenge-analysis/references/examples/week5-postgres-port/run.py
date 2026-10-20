import os, re, sqlite3, psycopg2, decimal, datetime as dt, sys
from gen import DATA
REPO=os.environ.get('WEEK_DIR','weekly/week-05-the-close')+'/'   # folder holding gold_submit.sql and Claude_gold_submit_Postgres.sql
def split_tasks(sql):
    parts=re.split(r'^-- task: (\w+)\s*$',sql,flags=re.M)
    return parts[0], list(zip(parts[1::2],parts[2::2]))
# ---- sqlite (gold)
gold=open(REPO+'gold_submit.sql').read()
_,gt=split_tasks(gold)
sl=sqlite3.connect(':memory:')
for t,(cols,rows) in DATA.items():
    sl.execute(f"create table {t} ({','.join(c+' TEXT' for c in cols)})")
    sl.executemany(f"insert into {t} values ({','.join('?'*len(cols))})",rows)
for name,body in gt:
    body=body.strip().rstrip(';')
    sl.execute(f"create table {name} as {body}")
# ---- postgres
pg=psycopg2.connect(dbname='dd',user='postgres',host=os.environ.get('PGHOST','127.0.0.1'),password=os.environ.get('PGPASSWORD','pw')); pg.autocommit=True
cur=pg.cursor()
cur.execute("drop schema public cascade; create schema public;")
for t,(cols,rows) in DATA.items():
    cur.execute(f"create table {t} ({','.join(c+' TEXT' for c in cols)})")
    cur.executemany(f"insert into {t} values ({','.join(['%s']*len(cols))})",rows)
mine=open(REPO+'Claude_gold_submit_Postgres.sql').read()
setup,pt=split_tasks(mine)
if 'CREATE OR REPLACE' in setup: cur.execute(setup)
for name,body in pt:
    body='\n'.join(l for l in body.splitlines() if not l.startswith('-- ===')); body=body[:body.rfind(';')] if ';' in body else body; body=body.strip()
    cur.execute(f"create table {name} as {body}")
# ---- compare
def norm(v):
    if v is None: return None
    if isinstance(v,(decimal.Decimal,float)): return round(float(v),6)
    if isinstance(v,(dt.datetime,)): return v.strftime('%Y-%m-%d %H:%M:%S')
    if isinstance(v,dt.date): return v.isoformat()
    return v
def getrows(c,q): 
    c.execute(q); return [tuple(norm(x) for x in r) for r in c.fetchall()]
class W:  # sqlite cursor wrapper
    def __init__(s,c): s.c=c
    def execute(s,q): s.cur=s.c.execute(q)
    def fetchall(s): return s.cur.fetchall()
sw=W(sl)
for name,cols in [('payments_history','rk,pid,mid,status_n,amt,stl,cur,created_ts,captured_ts,updated_ts,loaded_ts,order_ref,batch_day,eff_day'),
                  ('fx_history','rk,cur,rate_day,rate,loaded_ts'),('merchants_history','rk,mid,country,is_test,batch_day,loaded_ts')]:
    cols2=cols.replace('rk,',''); a=getrows(sw,f"select {cols2} from {name}"); b=getrows(cur,f"select {cols2} from {name}")
    print('  distinct rk sqlite/pg:',getrows(sw,f'select count(distinct rk) from {name}'),getrows(cur,f'select count(distinct rk) from {name}'))
    from collections import Counter
    ca,cb=Counter(a),Counter(b)
    diff_a=list((ca-cb).elements()); diff_b=list((cb-ca).elements())
    print(f"{name}: sqlite={len(a)} pg={len(b)} only_sqlite={len(diff_a)} only_pg={len(diff_b)}")
    for x,y in list(zip(sorted(diff_a,key=str),sorted(diff_b,key=str)))[:4]:
        print('   S:',x); print('   P:',y)
cols='payment_id,status,amount_usd,settled_usd,settled_in_period_usd,captured_at,order_ref,merchant_country'
a={r[0]:r for r in getrows(sw,f"select {cols} from fct_payments")}
b={r[0]:r for r in getrows(cur,f"select {cols} from fct_payments")}
print("fct_payments: sqlite",len(a),"pg",len(b),"keys only sqlite",len(set(a)-set(b)),"only pg",len(set(b)-set(a)))
bad=0; names=cols.split(',')
from collections import defaultdict
bycol=defaultdict(int); ex={}
for k in set(a)&set(b):
    for i,n in enumerate(names):
        x,y=a[k][i],b[k][i]
        same = (x==y) or (isinstance(x,float) and isinstance(y,float) and abs(x-y)<=0.0)
        if not same: bycol[n]+=1; ex.setdefault(n,(k,x,y))
print("column mismatches:",dict(bycol)); print(ex)
