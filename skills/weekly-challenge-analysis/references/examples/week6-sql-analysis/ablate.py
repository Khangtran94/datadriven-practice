import os, re, sys
from run import *
seed=int(os.environ.get('SEED','7'))
uv,tr,lo=gen(seed)
src=open(REPO+'/dag.sql').read()
g=run_dag(SQLiteEng(), REPO+'/gold_submit.sql', GOLD_HIST, GOLD_FINAL, uv,tr,lo)
G,gc=g['storage_charges']; gd={r[0]:dict(zip(gc,r)) for r in G}

def rep(s, old, new, count=1):
    assert s.count(old)==count, (old[:60], s.count(old))
    return s.replace(old,new)

def p_state_nonnull(s):
    return rep(s,"MAX(CASE WHEN event_rank = 1 THEN visit_state_n END) AS visit_state",
      "substr(MAX(CASE WHEN visit_state_n IS NOT NULL THEN printf('%09d',999999999-event_rank)||visit_state_n END),10) AS visit_state")

def p_state_map(s):
    s=rep(s,"""'discharged', 'discharge',
                'disch', 'dsch'""","""'discharged', 'discharge', 'dischgd', 'dischd', 'disch', 'unloaded', 'dsch'""")
    s=rep(s,"""'held', 'hold', 'on_hold', 'onhold'""","""'held', 'hold', 'on_hold', 'holding', 'onhold'""")
    s=rep(s,"""'gated_out', 'gate_out', 'gateout',
                'out_gated', 'gate_out_complete'""","""'gated_out', 'gate_out', 'gatedout', 'gateout', 'gated', 'exited', 'exit', 'departed', 'out'""")
    s=rep(s,"""'transshipped', 'transship',
                'transshipment', 'trans_shipped'""","""'transshipped', 'transhipped', 'transshipment', 'transship', 'tranship', 'trans', 'ts'""")
    return s

def p_ts(s):
    for col in ['dsch_time','gate_out_time','last_upd_time']:
        old=f"""CASE
                    WHEN upper(substr({col}, -1)) = 'Z'
                      OR substr({col}, -6, 1)
                         IN ('+', '-')
                    THEN {col}
                    ELSE {col} || '+08:00'
                END"""
        new=f"""CASE
                    WHEN {col} LIKE '% UTC' THEN replace({col}, ' UTC', '')
                    WHEN {col} GLOB '*:[0-9][0-9][+-][0-9][0-9]' THEN {col} || ':00'
                    WHEN {col} GLOB '*[0-9][+-][0-9][0-9][0-9][0-9]' THEN substr({col}, 1, length({col}) - 2) || ':' || substr({col}, -2)
                    WHEN {col} GLOB '*[0-9][+-][0-9][0-9]' THEN {col} || ':00'
                    WHEN upper(substr({col}, -1)) = 'Z' OR substr({col}, -6, 1) IN ('+', '-') THEN {col}
                    ELSE {col} || '+08:00'
                END"""
        s=rep(s,old,new)
    return s

def p_round(s):
    s=rep(s,"ELSE CAST(ROUND(d.charged_days*t.rate_usd_n*100.0,0) AS INTEGER)","ELSE CAST(ROUND(d.charged_days*t.rate_usd_n*10000.0,0) AS INTEGER)")
    s=rep(s,"printf('%.2f',COALESCE(SUM(p.charge_cents),0)/100.0) AS storage_usd",
      "printf('%.2f',((CASE WHEN COALESCE(SUM(p.charge_cents),0)<0 THEN -((-COALESCE(SUM(p.charge_cents),0)+50)/100) ELSE (COALESCE(SUM(p.charge_cents),0)+50)/100 END))/100.0) AS storage_usd")
    s=rep(s,"""printf('%.2f',COALESCE(SUM(CASE
                    WHEN p.charge_terminal_day <= '2026-10-19'
                    THEN p.charge_cents ELSE 0 END),0)/100.0)""","""printf('%.2f',((CASE WHEN COALESCE(SUM(CASE WHEN p.charge_terminal_day <= '2026-10-19' THEN p.charge_cents ELSE 0 END),0)<0 THEN -((-COALESCE(SUM(CASE WHEN p.charge_terminal_day <= '2026-10-19' THEN p.charge_cents ELSE 0 END),0)+50)/100) ELSE (COALESCE(SUM(CASE WHEN p.charge_terminal_day <= '2026-10-19' THEN p.charge_cents ELSE 0 END),0)+50)/100 END))/100.0)""")
    return s

def p_days(s):
    old="""CASE
            WHEN days_chg NOT GLOB '*[^0-9]*'
                 AND days_chg <> ''
            THEN CAST(days_chg AS INTEGER)

            WHEN substr(days_chg, 1, 1) = '-'
             AND length(days_chg) > 1
             AND substr(days_chg, 2)
                 NOT GLOB '*[^0-9]*'
            THEN CAST(days_chg AS INTEGER)
        END AS days_chg_n"""
    new="""CASE WHEN days_chg IS NOT NULL AND days_chg GLOB '*[0-9]*' AND ltrim(days_chg, '-') NOT GLOB '*[^0-9.]*'
                   AND length(days_chg) - length(ltrim(days_chg, '-')) <= 1
                   AND length(days_chg) - length(replace(days_chg, '.', '')) <= 1
              THEN CAST(days_chg AS REAL) END AS days_chg_n"""
    return rep(s,old,new)

def p_gkey(s):
    old="""CASE
            WHEN length(visit_gkey) = 8
             AND visit_gkey NOT GLOB '*[^0-9]*'
            THEN visit_gkey
        END AS visit_gkey_n"""
    new="""CASE WHEN visit_gkey NOT GLOB '*[^0-9]*' AND visit_gkey <> '' THEN visit_gkey
             WHEN visit_gkey GLOB '*[0-9].0' AND substr(visit_gkey, 1, length(visit_gkey) - 2) NOT GLOB '*[^0-9]*' THEN substr(visit_gkey, 1, length(visit_gkey) - 2) END AS visit_gkey_n"""
    return rep(s,old,new)

PATCHES=dict(state_nonnull=p_state_nonnull, state_map=p_state_map, ts=p_ts, round=p_round, days=p_days, gkey=p_gkey)

def run_variant(names):
    s=src
    for n in names: s=PATCHES[n](s)
    path='/tmp/dag_var.sql'; open(path,'w').write(s)
    u=run_dag(SQLiteEng(), path, USER_HIST, USER_FINAL, uv,tr,lo)
    U,uc=u['storage_charges']; ud={r[0]:dict(zip(uc,r)) for r in U}
    line='visits %3d/%3d extra %2d |'%(len(set(gd)&set(ud)),len(gd),len(set(ud)-set(gd)))
    for c in [c for c in gc if c!='visit_gkey']:
        ok=sum(1 for k in gd if k in ud and gd[k][c]==ud[k][c])
        line+=' %s=%d'%(c[:9],ok)
    print('%-44s'%('+'.join(names) or 'baseline'), line)

if __name__=='__main__':
    run_variant([])
    for n in PATCHES: run_variant([n])
    run_variant(list(PATCHES))

def p_tariff(s):
    return rep(s,"NULLIF(tariff_cd, '') AS tariff_cd_n","CASE WHEN upper(tariff_cd) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE tariff_cd END AS tariff_cd_n")
PATCHES['tariff']=p_tariff

def p_dayfb(s):
    s=rep(s,"""           substr(MAX(CASE WHEN tariff_cd_n IS NOT NULL
                      THEN printf('%09d',999999999-event_rank)||tariff_cd_n END),10) AS tariff_cd
    FROM visit_events_ranked""","""           substr(MAX(CASE WHEN tariff_cd_n IS NOT NULL
                      THEN printf('%09d',999999999-event_rank)||tariff_cd_n END),10) AS tariff_cd,
           MIN(COALESCE(restated_day_date, batch_day)) AS first_day
    FROM visit_events_ranked""")
    s=rep(s,"""       AND v.discharge_terminal_day >= l.valid_from
       AND (v.discharge_terminal_day < l.next_batch_day OR l.next_batch_day IS NULL)""","""       AND COALESCE(v.discharge_terminal_day, v.first_day) >= l.valid_from
       AND (COALESCE(v.discharge_terminal_day, v.first_day) < l.next_batch_day OR l.next_batch_day IS NULL)""")
    return s
PATCHES['dayfb']=p_dayfb

def p_camel(s):
    s=rep(s,"""            THEN json_extract(
                CASE
                    WHEN json_valid(remarks)
                    THEN remarks
                END,
                '$.booking_ref'
            )""","""            THEN COALESCE(json_extract(remarks, '$.booking_ref'), json_extract(remarks, '$.bookingRef'))""")
    return s
PATCHES['camel']=p_camel
