# shellcheck shell=bash
# Sourced by spinup.sh and teardown.sh. Refuses to touch any Kubernetes cluster
# that isn't a known LOCAL dev cluster, so a stray kubectl context can never
# point this at staging/prod. To use another cluster you own, allow it by its
# exact context name:  ./spinup.sh --allow-context my-dev-cluster
#
# Sets CLUSTER_CONTEXT for the caller to pass to skaffold/kubectl explicitly, so
# the context that was checked is the one that gets used.
# shellcheck disable=SC2034  # CLUSTER_CONTEXT is read by the sourcing script

LOCAL_CONTEXTS='docker-desktop docker-for-desktop minikube rancher-desktop orbstack colima colima-* kind-* k3d-*'

check_cluster() {
  local allowed="${1:-}" ctx pattern
  ctx="$(kubectl config current-context 2>/dev/null)" \
    || error "No current kubectl context. Enable Kubernetes in Docker Desktop (or start minikube/kind)."

  for pattern in $LOCAL_CONTEXTS; do
    # shellcheck disable=SC2053  # glob match on purpose
    if [[ "$ctx" == $pattern ]]; then CLUSTER_CONTEXT="$ctx"; return 0; fi
  done

  if [[ -n "$allowed" && "$allowed" == "$ctx" ]]; then
    printf '\033[1;33mWARNING:\033[0m using non-local context %s (allowed by --allow-context)\n' "$ctx" >&2
    CLUSTER_CONTEXT="$ctx"; return 0
  fi

  error "Refusing to use kubectl context '$ctx': it is not a known local cluster ($LOCAL_CONTEXTS).
       Switch with: kubectl config use-context docker-desktop
       Or, if '$ctx' is a dev cluster you own: re-run with --allow-context $ctx"
}
