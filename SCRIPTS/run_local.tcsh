#!/bin/tcsh
#
# run_local.tcsh - tcsh version of the local end-to-end runner for
# externals_rsidis. Prompts for the beam energy, target, E' grid,
# theta grid, and workflow name, then generates the runplan/input
# files, runs externals_all in parallel, and combines the tables.
#
# Usage:
#   ./run_local.tcsh
#
# Energies are in GeV and angles are in degrees.

# Resolve repository root (works when run from any directory).
set SCRIPT = $0
if ("$SCRIPT" !~ /*) set SCRIPT = "$cwd/$SCRIPT"
set SCRIPT_DIR = `dirname "$SCRIPT"`
cd "$SCRIPT_DIR/.."
set ROOT = $cwd
cd "$ROOT"

echo ""
echo "[run_local] externals_rsidis local runner (repo: $ROOT)"

# Optional: read all settings from a file instead of prompting.
# Usage: ./run_local.tcsh <settings_file>
if ($#argv > 0) then
    if (! -f "$1") then
        echo "[run_local] ERROR: settings file not found: $1"
        exit 1
    endif
    source "$1"
    goto settings_loaded
endif

# ---------------------------------------------------------------------------
# 1. Gather settings
# ---------------------------------------------------------------------------

echo ""
echo "Available targets in TARG/:"
foreach f (TARG/targ.*)
    set t = `basename "$f"`
    set t = `echo "$t" | sed 's/^targ\.//'`
    echo "  $t"
end
echo ""

echo -n "Target (extension) [12carbon25_hms]: "
set TARG = $<
if ("$TARG" == "") set TARG = "12carbon25_hms"
if (! -f "TARG/targ.$TARG") then
    echo "[run_local] ERROR: target file TARG/targ.$TARG does not exist"
    exit 1
endif

read_ebeam:
    echo -n "Beam energy [GeV] [8.5831]: "
    set EBEAM = $<
    if ("$EBEAM" == "") set EBEAM = "8.5831"
    echo "$EBEAM" | awk '{exit !($0 ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/)}'
    if ($status != 0) then
        echo "Invalid number: $EBEAM"
        goto read_ebeam
    endif

read_epmin:
    echo -n "Minimum scattered electron energy E' [GeV] [1.35]: "
    set EPMIN = $<
    if ("$EPMIN" == "") set EPMIN = "1.35"
    echo "$EPMIN" | awk '{exit !($0 ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/)}'
    if ($status != 0) then
        echo "Invalid number: $EPMIN"
        goto read_epmin
    endif

read_epmax:
    echo -n "Maximum scattered electron energy E' [GeV] [1.70]: "
    set EPMAX = $<
    if ("$EPMAX" == "") set EPMAX = "1.70"
    echo "$EPMAX" | awk '{exit !($0 ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/)}'
    if ($status != 0) then
        echo "Invalid number: $EPMAX"
        goto read_epmax
    endif

read_epstep:
    echo -n "E' step size [GeV] [0.01]: "
    set EPSTEP = $<
    if ("$EPSTEP" == "") set EPSTEP = "0.01"
    echo "$EPSTEP" | awk '{exit !($0 ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/)}'
    if ($status != 0) then
        echo "Invalid number: $EPSTEP"
        goto read_epstep
    endif

read_thmin:
    echo -n "Theta min [deg] [24.0]: "
    set THMIN = $<
    if ("$THMIN" == "") set THMIN = "24.0"
    echo "$THMIN" | awk '{exit !($0 ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/)}'
    if ($status != 0) then
        echo "Invalid number: $THMIN"
        goto read_thmin
    endif

read_thmax:
    echo -n "Theta max [deg] [34.0]: "
    set THMAX = $<
    if ("$THMAX" == "") set THMAX = "34.0"
    echo "$THMAX" | awk '{exit !($0 ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/)}'
    if ($status != 0) then
        echo "Invalid number: $THMAX"
        goto read_thmax
    endif

read_thstep:
    echo -n "Theta step size [deg] [0.2]: "
    set THSTEP = $<
    if ("$THSTEP" == "") set THSTEP = "0.2"
    echo "$THSTEP" | awk '{exit !($0 ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/)}'
    if ($status != 0) then
        echo "Invalid number: $THSTEP"
        goto read_thstep
    endif

echo -n "Workflow name (used for INP/OUT file names) [local_run]: "
set NAME = $<
if ("$NAME" == "") set NAME = "local_run"

# Default parallel jobs: half the CPUs, capped at 12.
if (-e /proc/cpuinfo) then
    set NCPU = `grep -c ^processor /proc/cpuinfo`
else
    set NCPU = `sysctl -n hw.ncpu`
endif
@ JOBS = $NCPU / 2
if ($JOBS > 12) @ JOBS = 12
if ($JOBS < 1) @ JOBS = 1

read_jobs:
    echo -n "Number of parallel angle jobs [$JOBS]: "
    set JOBSIN = $<
    if ("$JOBSIN" != "") then
        echo "$JOBSIN" | awk '{exit !($0 ~ /^[0-9]+$/)}'
        if ($status != 0) then
            echo "Invalid number: $JOBSIN"
            goto read_jobs
        endif
        @ JOBS = $JOBSIN
    endif

# Validate ranges.

settings_loaded:
if (! $?TARG) then
    echo "[run_local] ERROR: settings file is missing TARG"
    exit 1
endif
if (! $?EBEAM) then
    echo "[run_local] ERROR: settings file is missing EBEAM"
    exit 1
endif
if (! $?EPMIN) then
    echo "[run_local] ERROR: settings file is missing EPMIN"
    exit 1
endif
if (! $?EPMAX) then
    echo "[run_local] ERROR: settings file is missing EPMAX"
    exit 1
endif
if (! $?EPSTEP) then
    echo "[run_local] ERROR: settings file is missing EPSTEP"
    exit 1
endif
if (! $?THMIN) then
    echo "[run_local] ERROR: settings file is missing THMIN"
    exit 1
endif
if (! $?THMAX) then
    echo "[run_local] ERROR: settings file is missing THMAX"
    exit 1
endif
if (! $?THSTEP) then
    echo "[run_local] ERROR: settings file is missing THSTEP"
    exit 1
endif
if (! $?NAME) then
    echo "[run_local] ERROR: settings file is missing NAME"
    exit 1
endif
if (! $?JOBS) then
    echo "[run_local] ERROR: settings file is missing JOBS"
    exit 1
endif

awk -v a="$EPMIN" -v b="$EPMAX" 'BEGIN{exit !(b > a)}'
if ($status != 0) then
    echo "[run_local] ERROR: E' max must be greater than E' min"
    exit 1
endif
awk -v a="$THMIN" -v b="$THMAX" 'BEGIN{exit !(b > a)}'
if ($status != 0) then
    echo "[run_local] ERROR: theta max must be greater than theta min"
    exit 1
endif
awk -v s="$EPSTEP" 'BEGIN{exit !(s > 0)}'
if ($status != 0) then
    echo "[run_local] ERROR: E' step must be positive"
    exit 1
endif
awk -v s="$THSTEP" 'BEGIN{exit !(s > 0)}'
if ($status != 0) then
    echo "[run_local] ERROR: theta step must be positive"
    exit 1
endif

# The code stores beam energy with a 3-decimal fixed-width format (F6.3).
set EB = `echo "$EBEAM" | awk '{printf "%.3f", $1}'`
awk -v e="$EBEAM" -v eb="$EB" 'BEGIN{exit !(e+0 != eb+0)}'
if ($status == 0) then
    echo "[run_local] externals_all keeps 3 decimal places for Ebeam; $EBEAM will be used as $EB GeV"
endif

# ---------------------------------------------------------------------------
# 2. Build externals_all if needed
# ---------------------------------------------------------------------------

if (! -x externals_all) then
    echo "[run_local] Building externals_all..."
    make
endif
if (! -x run_extern) chmod +x run_extern

# ---------------------------------------------------------------------------
# 3. Generate RUNPLAN grid files and INP input files
# ---------------------------------------------------------------------------

set NTH = `awk -v a="$THMIN" -v b="$THMAX" -v s="$THSTEP" 'BEGIN{printf "%.0f", (b-a)/s}'`
set NP  = `awk -v a="$EPMIN" -v b="$EPMAX" -v s="$EPSTEP" 'BEGIN{printf "%.0f", (b-a)/s}'`

# Warn if a step does not land exactly on the requested maximum.
awk -v a="$THMIN" -v b="$THMAX" -v s="$THSTEP" -v n="$NTH" 'BEGIN{exit !(a+n*s != b)}'
if ($status == 0) then
    set lastangle = `awk -v a="$THMIN" -v n="$NTH" -v s="$THSTEP" 'BEGIN{printf "%.1f", a+n*s}'`
    echo "[run_local] theta step does not land exactly on theta max; last angle will be $lastangle deg"
endif
awk -v a="$EPMIN" -v b="$EPMAX" -v s="$EPSTEP" -v n="$NP" 'BEGIN{exit !(a+n*s != b)}'
if ($status == 0) then
    set lastp = `awk -v a="$EPMIN" -v n="$NP" -v s="$EPSTEP" 'BEGIN{printf "%.4f", a+n*s}'`
    echo "[run_local] E' step does not land exactly on E' max; last point will be $lastp GeV"
endif

mkdir -p INP RUNPLAN OUT runout

set ANGLES = /tmp/run_local_angles.$$
set BASES  = /tmp/run_local_bases.$$
awk -v a="$THMIN" -v n="$NTH" -v s="$THSTEP" 'BEGIN{for(i=0;i<=n;i++) printf "%.1f\n", a+i*s}' > $ANGLES
rm -f $BASES

foreach ang (`cat $ANGLES`)
    set angp = `echo "$ang" | tr . p`
    set base = "${NAME}_${angp}_${TARG}"
    echo "$base" >> $BASES

    set runplan = "RUNPLAN/${EB}gev_th_${ang}deg.inp"
    awk -v eb="$EBEAM" -v pmin="$EPMIN" -v pstep="$EPSTEP" -v np="$NP" -v th="$ang" 'BEGIN{for(j=0;j<=np;j++){p=pmin+j*pstep; printf "%6.3f %7.4f %7.4f\n", eb, p, th}}' > $runplan

    echo "input files for EXTERNAL: runplan/target/output" > "INP/${base}.inp"
    echo "RUNPLAN/${EB}gev_th_${ang}deg.inp" >> "INP/${base}.inp"
    echo "TARG/targ.${TARG}" >> "INP/${base}.inp"
    echo "OUT/${EB}gev_${ang}_${TARG}_details.out" >> "INP/${base}.inp"
end

set NBASES = `wc -l < $BASES | tr -d ' '`
echo "[run_local] Prepared $NBASES angle files for target '$TARG'"

# ---------------------------------------------------------------------------
# 4. Confirm and run
# ---------------------------------------------------------------------------

echo ""
echo -n "Proceed? [Y/n]: "
set PROCEED = $<
if ("$PROCEED" =~ [Nn]*) then
    echo "[run_local] Aborted."
    rm -f $ANGLES $BASES
    exit 0
endif

echo "[run_local] Running externals_all (logs: runout/<name>.out, results: OUT/<name>.out)..."
@ count = 0
foreach base (`cat $BASES`)
    ./run_extern "$base" &
    @ count++
    if ($count >= $JOBS) then
        wait
        @ count = 0
    endif
end
wait

# ---------------------------------------------------------------------------
# 5. Verify outputs and combine
# ---------------------------------------------------------------------------

@ missing = 0
foreach base (`cat $BASES`)
    if (! -s "OUT/${base}.out") then
        echo "[run_local] missing or empty output: OUT/${base}.out"
        @ missing++
    endif
end
if ($missing > 0) then
    echo "[run_local] ERROR: some jobs failed; inspect runout/*.out"
    rm -f $ANGLES $BASES
    exit 1
endif

set combined = "OUT/${NAME}_${TARG}.out"
cat SCRIPTS/header.txt > $combined
foreach base (`cat $BASES`)
    cat "OUT/${base}.out" >> $combined
end

rm -f $ANGLES $BASES

echo "[run_local] Done."
echo "  Master table : $combined"
echo "  Per-angle    : OUT/${NAME}_*_${TARG}.out (and _int.out)"
echo "  Logs         : runout/${NAME}_*_${TARG}.out"