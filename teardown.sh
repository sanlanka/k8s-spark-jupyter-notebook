#!/usr/bin/env bash
#
# Remove everything spinup.sh deployed (via Skaffold).
#
#   ./teardown.sh                        # delete the Spark + Jupyter release
#   ./teardown.sh --namespace            # ...and delete the 'api' namespace too
#   ./teardown.sh --allow-context NAME   # on a non-local cluster you own
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
# shellcheck source=scripts/cluster-guard.sh
source scripts/cluster-guard.sh

DELETE_NAMESPACE=false
ALLOW_CONTEXT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) DELETE_NAMESPACE=true; shift ;;
    --allow-context)
      [[ -n "${2:-}" ]] || error "$1 needs a context name"
      ALLOW_CONTEXT="$2"; shift 2 ;;
    *) error "Unknown argument: $1 (use --namespace and/or --allow-context NAME)" ;;
  esac
done

check_cluster "$ALLOW_CONTEXT"          # never delete from a non-local cluster by accident

# skaffold.yaml templates these; values don't matter for a delete.
export PROJECT_VALUES="$PWD/charts/spark/values.yaml"

info "Deleting the Skaffold deployment from '$CLUSTER_CONTEXT'..."
skaffold delete --kube-context "$CLUSTER_CONTEXT" 2>/dev/null || true

if $DELETE_NAMESPACE; then
  info "Deleting namespace 'api'..."
  kubectl --context "$CLUSTER_CONTEXT" delete namespace api --ignore-not-found
fi

info "Teardown complete."
