#!/usr/bin/env python3
"""Read-only: list week folders and say what each one needs.

Python week : README.md + handler.py + gold_submit.py   -> Claude_Analysis.md
SQL week    : README.md + dag.sql + gold_submit.sql      -> Claude_Analysis.md, and a
              Claude_gold_submit_Postgres.sql when gold_submit.sql is not PostgreSQL.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = sys.argv[1] if len(sys.argv) > 1 else "https://github.com/Khangtran94/datadriven-practice.git"
PY_NEEDED = {"README.md", "handler.py", "gold_submit.py"}
SQL_NEEDED = {"README.md", "dag.sql", "gold_submit.sql"}
COMPANION = "Claude_gold_submit_Postgres.sql"

# Rough signs only. The skill still requires reading the SQL to confirm the dialect.
SQLITE_SIGNS = [r"\bGLOB\b", r"\bquote\(", r"\binstr\(", r"'unixepoch'", r"\bjson_extract\(", r"\bchar\(\s*\d"]
POSTGRES_SIGNS = [r"::\w+", r"\bILIKE\b", r"\bjsonb\b", r"->>", r"\bgenerate_series\(", r"\bDISTINCT ON\b", r"\bNOW\(\)"]


def guess_dialect(sql):
    sqlite = sum(bool(re.search(p, sql, re.I)) for p in SQLITE_SIGNS)
    pg = sum(bool(re.search(p, sql, re.I)) for p in POSTGRES_SIGNS)
    if sqlite and sqlite >= pg:
        return "SQLite (looks like)"
    if pg and not sqlite:
        return "PostgreSQL (looks like)"
    return "unknown, read the SQL"


def week_status(d, files):
    py_missing = PY_NEEDED - files
    sql_missing = SQL_NEEDED - files
    if not py_missing:
        kind, missing = "python", set()
    elif not sql_missing:
        kind, missing = "sql", set()
    else:
        # report the type that is closer to complete
        kind, missing = ("sql", sql_missing) if len(sql_missing) < len(py_missing) else ("python", py_missing)
    return kind, missing


with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "clone", "--depth", "1", "-q", REPO, tmp], check=True)
    weekly = Path(tmp) / "weekly"
    print(f"{'folder':32} status")
    for d in sorted(p for p in weekly.iterdir() if p.is_dir()):
        files = {p.name for p in d.iterdir()}
        kind, missing = week_status(d, files)
        notes = []
        if "Claude_Analysis.md" in files:
            notes.append("analysis: skip, Claude_Analysis.md already exists")
        elif missing:
            notes.append(f"analysis: wait, {kind} week missing {', '.join(sorted(missing))}")
        else:
            gold = (d / ("gold_submit.py" if kind == "python" else "gold_submit.sql")).read_text(errors="ignore")
            warn = ""
            if kind == "python" and not re.search(r"^class\s+Handler", gold, re.M):
                warn = " (warning: gold has no Handler class)"
            notes.append(f"analysis: READY ({kind}){warn}")
        if kind == "sql" and not missing:
            dialect = guess_dialect((d / "gold_submit.sql").read_text(errors="ignore"))
            if dialect.startswith("PostgreSQL"):
                notes.append(f"postgres: not needed, gold is {dialect}")
            elif COMPANION in files:
                notes.append(f"postgres: {COMPANION} exists, do not overwrite (gold: {dialect})")
            else:
                notes.append(f"postgres: NEEDED, {COMPANION} missing (gold: {dialect})")
        print(f"{d.name:32} " + " | ".join(notes))
