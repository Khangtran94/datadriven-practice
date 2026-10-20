import random, json, datetime as dt, os
random.seed(int(os.environ.get('SEED','23')))
D=dt.date
def nulls(): return random.choice(['', 'null', 'NULL', 'N/A', '-', 'None', '\\N', '?', ' ', 'nan'])
def maybe_null(v,p=0.04): return nulls() if random.random()<p else v
def pad(s,p=0.1):
    return random.choice([' ','\t',''])+s+random.choice([' ','\n','']) if random.random()<p else s

def ts_variants(t):  # t: datetime UTC
    r=random.random()
    if r<0.30: return t.strftime('%Y-%m-%d %H:%M:%S')
    if r<0.45: return t.strftime('%Y-%m-%dT%H:%M:%SZ')
    if r<0.55: return t.strftime('%Y-%m-%dT%H:%M:%S')+'+00:00'
    if r<0.62: return t.strftime('%Y-%m-%dT%H:%M:%S.%f')+'Z'
    if r<0.68: return str(int(t.replace(tzinfo=dt.timezone.utc).timestamp()))
    if r<0.74: return str(int(t.replace(tzinfo=dt.timezone.utc).timestamp()*1000))
    if r<0.80: # local offset
        off=random.choice([(5,30),(-8,0),(9,0),(1,0)]); lt=t+dt.timedelta(hours=off[0],minutes=off[1] if off[0]>=0 else -off[1])
        sign='+' if off[0]>=0 else '-'
        return lt.strftime('%Y-%m-%dT%H:%M:%S')+f"{sign}{abs(off[0]):02d}:{off[1]:02d}"
    if r<0.84: 
        off=random.choice([5,-8,9]); lt=t+dt.timedelta(hours=off); sign='+' if off>=0 else '-'
        return lt.strftime('%Y-%m-%d %H:%M:%S')+f"{sign}{abs(off):02d}"
    if r<0.87:
        off=random.choice([(5,30),(9,0)]); lt=t+dt.timedelta(hours=off[0],minutes=off[1]); return lt.strftime('%Y-%m-%d %H:%M:%S')+f"+{off[0]:02d}{off[1]:02d}"
    if r<0.91: return t.strftime('%Y-%m-%d %H:%M:%S')+' UTC'
    if r<0.94: return t.strftime('%Y-%m-%dT%H:%M')+'Z'
    if r<0.96: return t.strftime('%Y-%m-%d')
    if r<0.98: return random.choice(['garbage','2026-13-45 00:00:00','1e9','0'])
    return nulls()

def day_variants(d):
    r=random.random()
    if r<0.6: return d.strftime('%Y-%m-%d')
    if r<0.75: return d.strftime('%Y%m%d')
    if r<0.85: return d.strftime('%Y/%m/%d')
    if r<0.93: return d.strftime('%Y-%m-%d')+'T03:00:00'
    if r<0.97: return 'bad-batch'
    return nulls()

CUR=['USD','EUR','GBP','JPY','KWD','CAD','VND','BHD','CLP','AUD']
BASE={'USD':1,'EUR':1.08,'GBP':1.27,'JPY':0.0067,'KWD':3.25,'CAD':0.74,'VND':0.00004,'BHD':2.65,'CLP':0.0011,'AUD':0.66}
start=D(2026,1,25); end=D(2026,3,10)
nights=[D(2026,2,1)+dt.timedelta(days=i) for i in range(30)]

# merchants
M=[]
for i in range(1,61):
    mid=i; country=random.choice(['US','VN','JP','DE','GB','KW']); test=random.random()<0.1
    M.append(dict(mid=mid,country=country,test=test,live_day=random.randint(3,20) if test else None,
                  move_day=random.randint(5,25) if random.random()<0.2 else None, gone=random.randint(10,28) if random.random()<0.05 else None))
def mid_fmt(i):
    r=random.random()
    if r<0.6: return f"M{i:06d}"
    if r<0.7: return f"m{i:06d}"
    if r<0.85: return str(i)
    if r<0.9: return f" M{i:06d} "
    if r<0.95: return f"M{i}"
    return nulls()
rows_m=[]
for n_i,n in enumerate(nights):
    if n_i==9: continue  # night with no copy
    for m in M:
        if m['gone'] is not None and n_i>=m['gone']: continue
        c=m['country']
        if m['move_day'] is not None and n_i>=m['move_day']: c={'US':'VN','VN':'JP','JP':'DE','DE':'GB','GB':'KW','KW':'US'}[c]
        test = m['test'] and (m['live_day'] is None or n_i<m['live_day'])
        ctry=random.choice([c,c,c.lower(),' '+c+' ',c.capitalize()]) if random.random()<0.15 else c
        if random.random()<0.02: ctry=random.choice(['','USA','X',None])
        it=random.choice(['t','f']) if False else ('true' if test else 'false')
        it=random.choice({'true':['true','t','1','Y','TRUE'],'false':['false','f','0','N','FALSE','no']}[it])
        lt=dt.datetime(n.year,n.month,n.day,2,random.randint(0,59),random.randint(0,59))+dt.timedelta(days=1)
        rows_m.append((mid_fmt(m['mid']),f"Shop {m['mid']}",ctry,it,day_variants(n),ts_variants(lt)))
# fx
rows_fx=[]
d=start
while d<=end:
    if d.weekday()<5:
        for c in CUR:
            if c=='USD': continue
            rate=BASE[c]*(1+random.uniform(-0.03,0.03))
            reps=[(rate,0)]
            if random.random()<0.08: reps.insert(0,(rate*random.choice([1.5,10,0.1]),0))  # wrong then fixed
            if random.random()<0.05: reps=[(1/rate,0)] if random.random()<0.5 else reps  # inverted
            for k,(r,_) in enumerate(reps):
                s=f"{r:.6f}"
                if random.random()<0.1: s=s.replace('.',',')
                if random.random()<0.03: s=random.choice(['0','-1','abc','1.2.3',''])
                lt=dt.datetime(d.year,d.month,d.day,1,random.randint(0,59))+dt.timedelta(days=k+ (1 if random.random()<0.2 else 0))
                rows_fx.append((day_variants(d) if random.random()<0.9 else nulls(), pad(random.choice([c,c.lower(),c])), s, day_variants(d+dt.timedelta(days=k)), ts_variants(lt)))
    d+=dt.timedelta(days=1)
# payments
def pid_fmt(h):
    r=random.random()
    if r<0.85: return 'pay_'+h
    if r<0.9: return 'PAY_'+h.upper()
    if r<0.95: return ' pay_'+h+' '
    if r<0.97: return 'pay_'+h[:5]
    return nulls()
STAT={'authorized':['authorized','Authorised','AUTHORIZED ','authorised'],'captured':['captured','CAPTURED',' Captured'],'failed':['failed','Refused','FAILED'],'voided':['voided','Cancelled','VOIDED'],'disputed':['disputed','chargeback','DISPUTED']}
def meta(order):
    r=random.random()
    if r<0.5: return json.dumps({'order_ref':order})
    if r<0.58: return json.dumps({'order_ref':order,'note':'x','n':3})
    if r<0.62: return json.dumps({'a':1,'order_ref':order})
    if r<0.66: return json.dumps({'order_ref':random.randint(1000,99999)})
    if r<0.70: return json.dumps(json.dumps({'order_ref':order}))
    if r<0.75: return json.dumps({'orderRef':order})
    if r<0.79: return '{"order_ref": "%s", "note": "tru'%order
    if r<0.82: return '{"order_ref": "OR'
    if r<0.84: return '{"order_ref":'
    if r<0.86: return json.dumps({'order_ref':None})
    if r<0.88: return json.dumps({'order_ref':random.choice(['','-','N/A','null','None',' '+order+' '])})
    if r<0.90: return '{"order_ref": '+str(round(random.uniform(1,500),1))+'}'
    if r<0.92: return json.dumps([1,2])
    return nulls()
rows_p=[]
for i in range(1800):
    h='%08x'%random.getrandbits(32)
    h=h[:8]
    cur=random.choices(CUR,[30,15,8,8,3,5,4,2,3,5])[0]
    mi=random.randint(1,60)
    created=dt.datetime(2026,2,1)+dt.timedelta(days=random.randint(0,27),seconds=random.randint(0,86399))
    major = random.random()<0.15
    mn=random.randint(100,500000)
    nstates=random.choice([1,2,2,3,4])
    st_seq=random.choice([['authorized','captured'],['authorized','failed'],['authorized','captured','disputed'],['authorized','voided'],['authorized']])
    order='ORD-%d'%random.randint(1,99999)
    cap=None; mv_nights=sorted(random.sample(range(30),k=random.randint(0,4)))
    n0=max(0,min(29,(created.date()-D(2026,2,1)).days))
    for s_i in range(nstates):
        n_i=min(29,n0+s_i*random.randint(1,3))
        night=nights[n_i]
        status=st_seq[min(s_i,len(st_seq)-1)]
        upd=created+dt.timedelta(days=(n_i-n0),hours=random.randint(0,5))
        if status in('captured','disputed') and cap is None: cap=upd
        landed=dt.datetime(night.year,night.month,night.day,2,random.randint(0,59))+dt.timedelta(days=1 if random.random()>0.2 else random.randint(2,3))
        amount=f"{mn/ (100 if cur not in('JPY','VND','CLP') else 1)* (1 if cur not in('KWD','BHD') else 0.1):.2f}" if major else str(mn)
        stl = random.choice([str(random.randint(-5000,50000)),f"{random.uniform(0,500):.2f}",'']) if status in ('captured','disputed') or random.random()<0.1 else random.choice(['',nulls()])
        row=[pid_fmt(h), day_variants(night) if random.random()<0.97 else nulls(),
             day_variants(night) if random.random()<0.08 else nulls() if random.random()<0.9 else '',
             ts_variants(landed), ts_variants(upd) if random.random()>0.02 else nulls(),
             pad(random.choice(STAT[status])) if random.random()<0.96 else nulls(),
             stl, ts_variants(created), ts_variants(cap) if cap and random.random()>0.1 else (nulls() if random.random()<0.7 else ''),
             pad(amount,0.05) if random.random()>0.05 else random.choice(['','N/A','1,250','1.2.3','-','--5','abc','-100']),
             random.choice([pad(cur),cur.lower()]) if random.random()>0.04 else random.choice(['XX','us','',nulls()]),
             mid_fmt(mi), meta(order)]
        # randomly blank fields that this service doesn't own (last row lacks older fields)
        if s_i>0 and random.random()<0.3:
            for k in (7,9,10,11,12): row[k]=nulls() if random.random()<.5 else ''
        rows_p.append(row)
        if random.random()<0.35: rows_p.append(list(row))  # duplicate in batch
        if random.random()<0.05: # same stamp fixed by hand
            r2=list(row); r2[6]=str(random.randint(0,9999)); r2[1]=day_variants(nights[min(29,n_i+1)]); rows_p.append(r2)
random.shuffle(rows_p)
COLS_P=['payment_id','_batch_id','_correction_for','_loaded_at','updated_at','status','settled','created_at','captured_at','amount','currency','merchant_id','metadata']
COLS_F=['rate_date','currency','usd_rate','_batch_id','_loaded_at']
COLS_M=['merchant_id','name','country','is_test','_batch_id','_loaded_at']
DATA={'raw_payments':(COLS_P,rows_p),'raw_fx_rates':(COLS_F,rows_fx),'raw_merchants':(COLS_M,rows_m)}
if __name__=='__main__':
    print({k:len(v[1]) for k,v in DATA.items()})
