#!/usr/bin/env bash
#
# Remove everything spinup.sh deployed (via Skaffold).
#
#   ./teardown.sh              # delete the Spark + Jupyter release
#   ./teardown.sh --namespace  # ...and delete the 'api' namespace too
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

info "Deleting the Skaffold deployment..."
skaffold delete 2>/dev/null || true

if [[ "${1:-}" == "--namespace" ]]; then
  info "Deleting namespace 'api'..."
  kubectl delete namespace api --ignore-not-found
fi

info "Teardown complete."
