#!/usr/bin/env bash
#
# One-stop-shop: install missing tooling, build the Jupyter image, deploy the
# Spark cluster + Jupyter via Skaffold, and hold the port-forwards.
#
# Just run:  ./spinup.sh
# Stop with: Ctrl-C   (resources are left running; use ./teardown.sh to remove)
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

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
kubectl cluster-info >/dev/null 2>&1 || \
  error "No reachable Kubernetes cluster. Enable Kubernetes in Docker Desktop (Settings > Kubernetes), or start minikube."

info "Tooling and cluster OK. Context: $(kubectl config current-context)"

# --- Versions: single source of truth is charts/spark/values.yaml ----------
VALUES_FILE=charts/spark/values.yaml

# Read `versions.<key>` from the values file (flat block, no yq needed).
read_version() {
  awk -v key="$1" '
    /^versions:/                 { in_block = 1; next }
    in_block && /^[^[:space:]#]/ { exit }
    in_block && $1 == key ":"    { v = $2; gsub(/["'\'']/, "", v); print v; exit }
  ' "$VALUES_FILE"
}

SPARK_VERSION="$(read_version spark)"
PYTHON_VERSION="$(read_version python)"
DELTA_SPARK_VERSION="$(read_version deltaSpark)"
JAVA_VERSION="$(read_version java)"
for v in SPARK_VERSION PYTHON_VERSION DELTA_SPARK_VERSION JAVA_VERSION; do
  [[ -n "${!v}" ]] || error "Missing versions.* entry for $v in $VALUES_FILE"
done
export SPARK_VERSION PYTHON_VERSION DELTA_SPARK_VERSION JAVA_VERSION

# --- Spin everything up ----------------------------------------------------
cat <<EOF

Building the image (Spark $SPARK_VERSION, Python $PYTHON_VERSION, Delta $DELTA_SPARK_VERSION, Java $JAVA_VERSION)
and deploying via Skaffold. Change versions in $VALUES_FILE.
Once ready:
  Jupyter       : http://localhost:8888   (token: spark123)
  Spark UI      : http://localhost:8080
  Spark Connect : sc://localhost:15002    (use the cluster from any local program)
Port-forwarding is handled by Skaffold. Press Ctrl-C to stop it.

EOF

# Mount this repo into Jupyter + workers so local files are readable in the pods.
export PROJECT_DIR="$PWD"
# Shared output folder (hostMount.warehouse) — create it so you own it, not the kubelet.
mkdir -p warehouse

# `skaffold dev` builds, deploys, and holds the portForward entries defined in
# skaffold.yaml. --cleanup=false keeps the cluster running after Ctrl-C.
exec skaffold dev --port-forward=user --cleanup=false --tail=false
