#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------
# Kyber per-operation detailed comparison (keygen / encaps / decaps)
# Parses "Time (us): mean" and "CPU cycles: mean" from speed_kem output.
# Supports runtime overrides: MODE, RUNS, DURATION, SKIP_BUILD
# -------------------------------------------------------------

# Allow overrides: ./script.sh MODE=detailed RUNS=5 DURATION=3 SKIP_BUILD=1
for arg in "$@"; do eval "$arg"; done

REPO_DIR="$HOME/liboqs"
BUILD_DIR="$REPO_DIR/build"
TEST_DIR="$BUILD_DIR/tests"

ALGOS=("Kyber512" "Kyber768" "Kyber1024")
RUNS="${RUNS:-10}"                # default repetitions
DURATION="${DURATION:-3}"         # default seconds per run
SKIP_BUILD="${SKIP_BUILD:-0}"     # 0=build if needed, 1=skip build
MODE="${MODE:-detailed}"          # placeholder for future modes (default detailed)

OUT_CSV="$TEST_DIR/kyber_ops_detailed_compare.csv"
PNG_US="$TEST_DIR/kyber_ops_detailed_time_us.png"
PNG_CYC="$TEST_DIR/kyber_ops_detailed_cycles.png"

say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }

say "⚙️  Configuration:"
echo "   MODE=$MODE  RUNS=$RUNS  DURATION=$DURATION  SKIP_BUILD=$SKIP_BUILD"

# -------------------------------------------------------------
# 0️⃣ Dependencies
# -------------------------------------------------------------
say "🧱 Checking Python dependencies…"
sudo apt update -qq
sudo apt install -y python3 python3-pip python3-numpy python3-matplotlib >/dev/null

# -------------------------------------------------------------
# 1️⃣ Ensure build exists (or build if not skipped)
# -------------------------------------------------------------
if [[ ! -x "$TEST_DIR/speed_kem" ]]; then
  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "❌ speed_kem not found and SKIP_BUILD=1 set. Please build first."
    exit 1
  fi
  say "🏗️  Configuring & building liboqs (Release)…"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"
  cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -DOQS_USE_OPENSSL=OFF ..
  make -j"$(nproc)"
else
  if [[ "$SKIP_BUILD" == "1" ]]; then
    say "⏩ Using existing build (SKIP_BUILD=1)."
  else
    say "✅ Build exists; continuing without rebuild."
  fi
fi

cd "$TEST_DIR"

# -------------------------------------------------------------
# 2️⃣ Run speed_kem for each algorithm
# -------------------------------------------------------------
say "🏃 Running speed_kem (-d $DURATION) for ${#ALGOS[@]} Kyber variants ($RUNS runs each)…"
RAW_DIR="$TEST_DIR/speedkem_raw"
mkdir -p "$RAW_DIR"

for alg in "${ALGOS[@]}"; do
  echo "→ $alg"
  rm -f "$RAW_DIR/${alg}.txt"
  for ((i=1; i<=RUNS; i++)); do
    ./speed_kem -d "$DURATION" "$alg" >> "$RAW_DIR/${alg}.txt"
    echo "  Run $i/$RUNS done"
  done
done
say "Raw outputs saved under: $RAW_DIR"

# -------------------------------------------------------------
# 3️⃣ Parse tables → CSV
# -------------------------------------------------------------
say "📄 Parsing Time (us) and Cycles into CSV…"
python3 - <<'PY'
import re, csv, pathlib
test_dir = pathlib.Path("~/liboqs/build/tests").expanduser()
raw_dir = test_dir/"speedkem_raw"
csvp = test_dir/"kyber_ops_detailed_compare.csv"
ops = ["keygen","encaps","decaps"]

def parse_table(txt):
    rows={}
    for line in txt.splitlines():
        if not any(line.strip().startswith(op) for op in ops):
            continue
        parts=[p.strip() for p in line.split("|")]
        if len(parts)<7: 
            continue
        op=parts[0].lower()
        nums=[re.findall(r"[0-9.]+",p) for p in parts[1:7]]
        flat=[float(n[0]) if n else 0 for n in nums]
        rows[op]=dict(
            iterations=int(flat[0]), total_s=flat[1],
            mean_us=flat[2], stdev_us=flat[3],
            mean_cycles=flat[4], stdev_cycles=flat[5]
        )
    return rows

algos=["Kyber512","Kyber768","Kyber1024"]
allrows=[]
for alg in algos:
    txt=(raw_dir/f"{alg}.txt").read_text()
    parsed=parse_table(txt)
    for op in ops:
        r=parsed.get(op)
        if r:
            allrows.append({
                "algorithm":alg,"operation":op,
                "mean_time_us":r["mean_us"],
                "stdev_time_us":r["stdev_us"],
                "mean_cycles":r["mean_cycles"],
                "stdev_cycles":r["stdev_cycles"]
            })
with csvp.open("w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=allrows[0].keys())
    w.writeheader(); w.writerows(allrows)
print(f"Wrote: {csvp}")
PY

# -------------------------------------------------------------
# 4️⃣ Plot grouped charts
# -------------------------------------------------------------
say "📊 Plotting comparison charts…"
python3 - <<'PY'
import csv, pathlib, numpy as np, matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt

csvp = pathlib.Path("~/liboqs/build/tests/kyber_ops_detailed_compare.csv").expanduser()
png_us = csvp.with_name("kyber_ops_detailed_time_us.png")
png_cyc = csvp.with_name("kyber_ops_detailed_cycles.png")

ops = ["keygen","encaps","decaps"]
algs = ["Kyber512","Kyber768","Kyber1024"]
data_us={op:{} for op in ops}; data_cyc={op:{} for op in ops}

with csvp.open() as f:
    for r in csv.DictReader(f):
        data_us[r["operation"]][r["algorithm"]]=float(r["mean_time_us"])
        data_cyc[r["operation"]][r["algorithm"]]=float(r["mean_cycles"])

def plot(metric, ylabel, out, title):
    x = np.arange(len(ops))
    w = 0.25
    plt.figure(figsize=(9,5))
    for i, a in enumerate(algs):
        vals = [metric[o].get(a, np.nan) for o in ops]
        plt.bar(x + i*w, vals, w, label=a)
    plt.xticks(x + w, ops)   # ✅ fixed line
    plt.ylabel(ylabel)
    plt.title(title)
    plt.legend()
    plt.tight_layout()
    plt.savefig(out, dpi=200)
    print("Saved:", out)

plot(data_us, "Mean time (µs per operation)", png_us, "Kyber keygen / encaps / decaps (µs)")
plot(data_cyc, "Mean CPU cycles per operation", png_cyc, "Kyber keygen / encaps / decaps (cycles)")
PY

# -------------------------------------------------------------
# 5️⃣ Done
# -------------------------------------------------------------
say "🗂️ Results ready → open in Windows Explorer:"
echo "\\\\wsl$\\Ubuntu\\home\\$USER\\liboqs\\build\\tests\\"

