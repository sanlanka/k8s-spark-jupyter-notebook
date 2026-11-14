#!/usr/bin/env bash
#
# One-stop-shop: install missing tooling, build the image, deploy the Spark
# cluster + Jupyter + Spark Connect via Skaffold, and hold the port-forwards.
#
#   ./spinup.sh                          # defaults from charts/spark/values.yaml
#   ./spinup.sh -f my-project.yaml       # + your project's overrides (yours win)
#   ./spinup.sh --allow-context NAME     # deploy to a non-local cluster you own
#
# Stop with: Ctrl-C   (resources are left running; use ./teardown.sh to remove)
#
set -euo pipefail

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '3,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# --- Arguments (resolved before cd, so -f paths are relative to where you are)
PROJECT_VALUES=""
ALLOW_CONTEXT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--values)
      [[ -n "${2:-}" ]] || error "$1 needs a file"
      [[ -f "$2" ]] || error "Values file not found: $2"
      PROJECT_VALUES="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
    --allow-context)
      [[ -n "${2:-}" ]] || error "$1 needs a context name"
      ALLOW_CONTEXT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) printf 'Unknown argument: %s\n\n' "$1" >&2; usage 1 ;;
  esac
done

cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=scripts/cluster-guard.sh
source scripts/cluster-guard.sh

# --- Install prerequisites (assume nothing) -------------------------------
ensure_brew() {
  command -v brew >/dev/null 2>&1 && return 0
  error "Homebrew is required to auto-install tools. Install it from https://brew.sh then re-run."
}

ensure_tool() {
  local bin="$1" pkg="${2:-$1}"
  if command -v "$bin" >/dev/null 2>&1; then return 0; fi
  info "$bin not found — installing via Homebrew..."
  ensure_brew
  brew install "$pkg"
}

ensure_tool docker         # Docker CLI (Docker Desktop provides the daemon)
ensure_tool kubectl
ensure_tool helm
ensure_tool skaffold

# --- Verify the environment -----------------------------------------------
docker info >/dev/null 2>&1 || error "Docker daemon not reachable. Start Docker Desktop and try again."
check_cluster "$ALLOW_CONTEXT"          # local clusters only, unless explicitly allowed
kubectl --context "$CLUSTER_CONTEXT" cluster-info >/dev/null 2>&1 || \
  error "Kubernetes context '$CLUSTER_CONTEXT' is not reachable. Enable Kubernetes in Docker Desktop (Settings > Kubernetes), or start minikube."

info "Tooling and cluster OK. Context: $CLUSTER_CONTEXT"

# --- Build settings: charts/spark/values.yaml, overridden by -f <file> -------
VALUES_FILE=charts/spark/values.yaml

# Print `<block>.<key>` from a values file: a top-level block of flat, one-line
# `key: value` entries (no yq needed). Strips quotes and trailing # comments.
read_key() {
  awk -v block="$2" -v key="$3" '
    $0 ~ "^" block ":"           { in_block = 1; next }
    in_block && /^[^[:space:]#]/ { exit }
    in_block && $1 == key ":" {
      sub(/^[^:]*:[[:space:]]*/, ""); sub(/[[:space:]]+#.*$/, "")
      gsub(/^["'\'']|["'\'']$/, ""); print; exit
    }' "$1"
}
# The project file wins when it sets the key; otherwise the chart default.
read_value() {
  local v=""
  [[ -n "$PROJECT_VALUES" ]] && v="$(read_key "$PROJECT_VALUES" "$1" "$2")"
  [[ -n "$v" ]] || v="$(read_key "$VALUES_FILE" "$1" "$2")"
  printf '%s' "$v"
}

SPARK_VERSION="$(read_value versions spark)"
PYTHON_VERSION="$(read_value versions python)"
DELTA_SPARK_VERSION="$(read_value versions deltaSpark)"
JAVA_VERSION="$(read_value versions java)"
for v in SPARK_VERSION PYTHON_VERSION DELTA_SPARK_VERSION JAVA_VERSION; do
  [[ -n "${!v}" ]] || error "Missing versions.* entry for $v in $VALUES_FILE"
done
EXTRA_MAVEN_PACKAGES="$(read_value extraPackages maven)"
EXTRA_PIP_PACKAGES="$(read_value extraPackages pip)"
JUPYTER_TOKEN="$(read_value jupyter token)"
export SPARK_VERSION PYTHON_VERSION DELTA_SPARK_VERSION JAVA_VERSION \
       EXTRA_MAVEN_PACKAGES EXTRA_PIP_PACKAGES
# Skaffold layers this on top of the chart defaults (same file twice if no -f).
export PROJECT_VALUES="${PROJECT_VALUES:-$PWD/$VALUES_FILE}"

# --- Spin everything up ----------------------------------------------------
cat <<EOF

Building the image (Spark $SPARK_VERSION, Python $PYTHON_VERSION, Delta $DELTA_SPARK_VERSION, Java $JAVA_VERSION)
  extra Maven: ${EXTRA_MAVEN_PACKAGES:-none}
  extra pip  : ${EXTRA_PIP_PACKAGES:-none}
  values     : $VALUES_FILE$( [[ "$PROJECT_VALUES" != "$PWD/$VALUES_FILE" ]] && echo " + $PROJECT_VALUES" )
and deploying to '$CLUSTER_CONTEXT' via Skaffold.
Once ready:
  Jupyter       : http://localhost:8888   (token: $JUPYTER_TOKEN)
  Spark UI      : http://localhost:8080
  Spark Connect : sc://localhost:15002    (use the cluster from any local program)
If a port is busy locally, Skaffold uses the next free one — see the
"Port forwarding" lines below. Press Ctrl-C to stop forwarding.

EOF

# Mount this repo into Jupyter + workers so local files are readable in the pods.
export PROJECT_DIR="$PWD"
# Shared output folder (hostMount.warehouse) — create it so you own it, not the kubelet.
mkdir -p warehouse

# `skaffold dev` builds, deploys, and holds the portForward entries defined in
# skaffold.yaml. --cleanup=false keeps the cluster running after Ctrl-C.
exec skaffold dev --kube-context "$CLUSTER_CONTEXT" \
  --port-forward=user --cleanup=false --tail=false
