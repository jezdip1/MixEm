#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PARADIGM="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["paradigm"])' "$PROJECT_ROOT/DEPLOYMENT.json")"
ACTION="${1:-main}"
case "$ACTION" in main|preflight|devices|ff|00|results|instructions) ;; *) echo "Unknown action: $ACTION" >&2; exit 2;; esac
CONFIG_FILE="${HAMMER_CONFIG_FILE:-/srv/hammerlab/config/$PARADIGM.env}"
[[ -r "$CONFIG_FILE" ]] || { echo "Missing configuration: $CONFIG_FILE" >&2; exit 3; }
set -a
# shellcheck disable=SC1090
source "$CONFIG_FILE"
set +a
export HAMMER_CODE_ROOT="$PROJECT_ROOT" HAMMER_MANAGED=1
: "${HAMMER_RESULTS_ROOT:?Missing results directory}"
: "${HAMMER_STIMULI_ROOT:?Missing stimulus directory}"
MATLAB_BIN="${HAMMER_MATLAB_BIN:-/usr/local/MATLAB/R2024b/bin/matlab}"
if [[ "$ACTION" == results ]]; then exec xdg-open "$HAMMER_RESULTS_ROOT"; fi
if [[ "$ACTION" == instructions ]]; then exec xdg-open "$PROJECT_ROOT/OPERATING.txt"; fi
[[ -x "$MATLAB_BIN" ]] || { echo "MATLAB unavailable: $MATLAB_BIN" >&2; exit 4; }
(cd -- "$PROJECT_ROOT" && sha256sum --quiet -c SHA256SUMS)
export HAMMER_GIT_COMMIT="$(cat "$PROJECT_ROOT/GIT_COMMIT")"
if [[ "$ACTION" == main || "$ACTION" == preflight ]]; then
    python3 "$PROJECT_ROOT/scripts/assets.py" verify "$PARADIGM" "$HAMMER_STIMULI_ROOT"
    export HAMMER_ASSETS_SHA256="$(sha256sum "$HAMMER_STIMULI_ROOT/ASSETS.json" | cut -d ' ' -f1)"
fi
if [[ "$ACTION" != devices ]]; then
    if [[ -z "${HAMMER_TRIGGER_PORT:-}" ]]; then
        shopt -s nullglob
        pico_ports=(/dev/serial/by-id/usb-Raspberry_Pi_Pico_*-if00)
        if [[ ${#pico_ports[@]} -ne 1 ]]; then
            echo "Found ${#pico_ports[@]} Pico devices. Set HAMMER_TRIGGER_PORT in $CONFIG_FILE." >&2
            exit 5
        fi
        export HAMMER_TRIGGER_PORT="${pico_ports[0]}"
    fi
    [[ -r "$HAMMER_TRIGGER_PORT" && -w "$HAMMER_TRIGGER_PORT" ]] || {
        echo "Trigger unavailable to $(id -un): $HAMMER_TRIGGER_PORT" >&2; exit 5;
    }
fi
export MIXEM_SYNC=serial MIXEM_SYNC_PORT="${HAMMER_TRIGGER_PORT:-}"
export MIXEM_SKIP_SYNCTESTS="${HAMMER_SKIP_SYNC_TESTS:-0}"
# The normal desktop launcher always uses actual participant responses.
export MUSEM_AUTOPILOT=0
unset MUSEM_SUBJID MIXEM_STAGE MIXEM_DEBUGCLICK
mkdir -p "$HAMMER_RESULTS_ROOT/launcher_logs"
LOCK_FILE="${HAMMER_LOCK_FILE:-/data/results/.mixem-musem-session.lock}"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo 'MixEm or MusEm is already open. Close its MATLAB before launching another.' >&2; exit 6; }
LOG_FILE="$HAMMER_RESULTS_ROOT/launcher_logs/$(date +%Y%m%d_%H%M%S)_${ACTION}_$$.log"
cd -- "$PROJECT_ROOT"
echo "Starting $PARADIGM / $ACTION; MATLAB stays open after completion."
exec "$MATLAB_BIN" -desktop -sd "$PROJECT_ROOT" -logfile "$LOG_FILE" -r \
    "try, hammer.entry('$PARADIGM','$ACTION'); catch me, disp(getReport(me,'extended','hyperlinks','off')); end"
