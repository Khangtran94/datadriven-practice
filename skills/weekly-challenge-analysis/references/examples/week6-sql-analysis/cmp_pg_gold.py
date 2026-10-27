import os, sys
from run import *
KEYS={'unit_visit_history':['src_key'],'tariff_rate_history':['tariff_cd','eff_date'],'line_operator_history':['line_scac','snap_day'],
      'visits_latest':['visit_gkey'],'visit_days':['visit_gkey','eff_day'],'tariff_day_rates':['tariff_cd','day'],
      'visit_charges':['visit_gkey'],'visit_lines':['visit_gkey'],'storage_charges':['visit_gkey']}
port=sys.argv[1]
tot_bad=0
for seed in [int(x) for x in os.environ.get('SEEDS','7,11,23').split(',')]:
    uv,tr,lo=gen(seed)
    g=run_dag(SQLiteEng(), REPO+'/gold_submit.sql', GOLD_HIST, GOLD_FINAL, uv,tr,lo)
    p=run_dag(PGEng(), port, GOLD_HIST, GOLD_FINAL, uv,tr,lo)
    print('seed',seed,'raw rows: unit_visit',len(uv),'tariff',len(tr),'line_operator',len(lo))
    for t,k in KEYS.items():
        r=compare(g[t],p[t],t,k)
        bad=r['only_a']+r['only_b']+sum(r['mismatches'].values())
        tot_bad+=bad
        # also check the table is not mostly NULL
        rows,cols=g[t]
        nn={c:sum(1 for x in rows if x[i] is not None) for i,c in enumerate(cols)}
        print('  %-22s gold=%5d pg=%5d only_gold=%d only_pg=%d mism=%s %s'%(t,r['rows_a'],r['rows_b'],r['only_a'],r['only_b'],r['mismatches'],r['examples'][:2] if bad else ''))
        if t=='storage_charges': print('    non-null per column (gold):',nn)
print('TOTAL DIFFERENCES',tot_bad)
