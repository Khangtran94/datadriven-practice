import json, random, sys
random.seed(7)
N_KEYS = int(sys.argv[1]); out = sys.argv[2]
TESTS = [("2345-7","Glucose","mg/dL",(60,300)),("2951-2","Sodium","mmol/L",(125,150)),
         ("2823-3","Potassium","mmol/L",(3,6)),("2160-0","Creatinine","mg/dL",(0.4,3)),
         ("718-7","Hemoglobin","g/dL",(8,18)),("6690-2","WBC","10*3/uL",(3,15))]
def msg(i, status, rev=0):
    code,name,unit,(lo,hi) = TESTS[i % 6]
    pid = "%08d" % (10_000_000 + (i * 7919) % 80_000_000)
    day = 1 + i % 28; hh = i % 24; mm = (i*7) % 60
    obs = "202601%02d%02d%02d" % (day, hh, mm)
    ts = "202601%02d%02d%02d%02d" % (day, hh, (mm+30) % 60, rev % 60)
    if i % 3 == 0: obs += "-0500"; ts += "-0500"       # a third carry an offset, the rest need the zone rule
    val = "%.2f" % random.uniform(lo, hi)
    m = ("MSH|^~\\&|LAB|HOSP|EHR|HOSP|%s||ORU^R01|C%d_%d|P|2.5\rPID|1||%s^^^HOSP^MR\r"
         "OBR|1||LAB%07d||||%s\rOBX|1|NM|%s^%s^LN||%s|%s|||||%s") % (ts, i, rev, pid, i, obs, code, name, val, unit, status)
    return json.dumps({"seq": i, "connection": "c1", "message": m})
with open(out, "w") as f:
    lines = 0
    for i in range(N_KEYS):                                   # phase 1: first message per key
        st = "P" if i % 4 == 0 else ("C" if i % 50 == 0 else "F")
        f.write(msg(i, st) + "\n"); lines += 1
    extra = list(range(0, N_KEYS, 3))                          # phase 2: revisions / replays for a third of the keys
    random.shuffle(extra)
    for j, i in enumerate(extra[: int(N_KEYS * 0.33)]):
        if i % 4 == 0:   f.write(msg(i, "F", rev=1) + "\n")    # prelim -> final
        elif i % 9 == 0: f.write(msg(i, "P", rev=2) + "\n")    # replayed preliminary after its final
        else:            f.write(msg(i, "F") + "\n")           # exact resend
        lines += 1
print("lines", lines, "keys", N_KEYS)
