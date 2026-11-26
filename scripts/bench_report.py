#!/usr/bin/env python3
"""Summarise Splash-3 runs (build/bench_runs/<bench>_p<N>/sim.log) as CSV.

Speedup = ROI cycles on 1 hart / ROI cycles on 2 harts, the normalisation of the
paper's Figure 4. Stalls/instr and mem-ops/instr are the paper's Table 2 metrics,
summed over all harts inside the ROI (stall = CVA6 issue-stall cycle).
"""
import glob, os, re, sys

d = sys.argv[1] if len(sys.argv) > 1 else "build/bench_runs"
runs = {}
for log in glob.glob(os.path.join(d, "*_p[12]", "sim.log")):
    name = os.path.basename(os.path.dirname(log))
    bench, p = name.rsplit("_p", 1)
    t = open(log, errors="replace").read()
    r = {"ok": bool(re.search(r"EXIT code=0 ", t))}
    m = re.search(r"ROI cycles=(\d+)", t)
    r["roi"] = int(m.group(1)) if m else None
    cores = re.findall(r"ROI core\d+ instr=(\d+) loads=(\d+) stores=(\d+) stall_issue=(\d+)", t)
    r["instr"] = sum(int(c[0]) for c in cores)
    r["mem"] = sum(int(c[1]) + int(c[2]) for c in cores)
    r["stall"] = sum(int(c[3]) for c in cores)
    runs.setdefault(bench, {})[int(p)] = r

print("benchmark,roi_cycles_1core,roi_cycles_2core,speedup_2v1,stalls_per_instr_2core,memops_per_instr_2core,ok_1core,ok_2core")
for b in sorted(runs):
    r1, r2 = runs[b].get(1, {}), runs[b].get(2, {})
    sp = (r1["roi"] / r2["roi"]) if r1.get("roi") and r2.get("roi") else ""
    spi = (r2["stall"] / r2["instr"]) if r2.get("instr") else ""
    mpi = (r2["mem"] / r2["instr"]) if r2.get("instr") else ""
    f = lambda x: f"{x:.3f}" if isinstance(x, float) else str(x if x is not None else "")
    print(",".join([b, f(r1.get("roi")), f(r2.get("roi")), f(sp), f(spi), f(mpi),
                    str(r1.get("ok", "")), str(r2.get("ok", ""))]))
